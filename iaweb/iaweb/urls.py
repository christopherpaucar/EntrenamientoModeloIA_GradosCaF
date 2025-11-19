from django.contrib import admin
from django.urls import path
from predictor.views import convertir

urlpatterns = [
    path('admin/', admin.site.urls),
    path("", convertir),
]