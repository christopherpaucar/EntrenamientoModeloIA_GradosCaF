import os
import numpy as np
import threading
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

    if request.method == "POST":
        try:
            valor = float(request.POST.get("valor"))
        except (TypeError, ValueError):
            valor = None

        if valor is not None:
            modelo = _get_model()
            # Asegurar que la entrada tiene la forma esperada por el modelo
            prediccion = modelo.predict(np.array([valor]))
            resultado = float(prediccion[0])

    return render(request, "index.html", {"resultado": resultado})
