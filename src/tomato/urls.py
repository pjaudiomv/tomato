from django.conf import settings
from django.conf.urls import url
from django.contrib import admin
from django.contrib.staticfiles.views import serve
from django.urls import path
import re
from .api import views

urlpatterns = [
    path('admin/', admin.site.urls),
    url(r'main_server/client_interface/(?P<format>json)/', views.semantic_query),
    url(r'^%s/(?P<path>.*)$' % re.escape(settings.STATIC_URL.strip('/')),
        serve, kwargs={'insecure':True}),
]