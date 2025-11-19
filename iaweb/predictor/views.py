import os
import json
import numpy as np
import threading
from datetime import datetime
from django.shortcuts import render
from django.conf import settings

# Carga diferida y thread-safe del modelo para evitar cargar TF en el import
_model_lock = threading.Lock()
_modelo = None

def _get_model():
    global _modelo
    if _modelo is None:
        with _model_lock:
            if _modelo is None:
                # Importar dentro de la función para evitar costos en el import del módulo
                from keras.models import load_model
                model_path = os.path.join(settings.BASE_DIR, 'predictor', 'modelo', 'modelo.h5')
                _modelo = load_model(model_path)
    return _modelo


def convertir(request):
    resultado = None
    used_fallback = False
    # preparar datos de ejemplo para el gráfico de entrenamiento (decaimiento de pérdida)
    x = np.linspace(0, 5, 80)
    loss_array = 0.5 * np.exp(-x) + 0.02 * np.sin(np.linspace(0, 20, x.size))
    loss_list = [float(x) for x in loss_array]

    # historial simple guardado en sesión (lista de dicts)
    history = request.session.get('history', [])
    if request.method == "POST":
        try:
            valor = float(request.POST.get("valor"))
        except (TypeError, ValueError):
            valor = None

        # permitir limpiar historial 
        if request.POST.get('clear_history'):
            history = []
            request.session['history'] = history
            request.session.modified = True
            # no continuar con predicción
            valor = None

        if valor is not None:
            # Intentar usar el modelo; si falla (memoria, import, runtime), usar la fórmula de reserva
            try:
                modelo = _get_model()
                # Asegurar que la entrada tiene la forma esperada por el modelo
                prediccion = modelo.predict(np.array([valor]))
                resultado = float(prediccion[0])
            except Exception:
                # Fallback seguro: conversión clásica
                resultado = float(valor * 1.8 + 32)
                used_fallback = True
            # registrar en el historial (timestamp, celsius, fahrenheit)
            entry = {
                'when': datetime.utcnow().isoformat() + 'Z',
                'celsius': float(valor),
                'fahrenheit': round(float(resultado), 2),
            }
            history.append(entry)
            # limitar historial a últimas 20 entradas
            history = history[-20:]
            request.session['history'] = history
            request.session.modified = True

    # pasar datos para renderizar gráfico y tabla
    context = {
        'resultado': resultado,
        'loss_json': json.dumps(loss_list),
        'history': list(reversed(history)),
        'used_fallback': used_fallback,
    }
    return render(request, "index.html", context)
