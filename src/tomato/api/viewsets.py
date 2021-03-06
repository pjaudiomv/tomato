from rest_framework import viewsets
from rest_framework.pagination import PageNumberPagination
from . import models, serializers


class StandardResultsSetPagination(PageNumberPagination):
    page_size = 1000
    page_size_query_param = 'page_size'
    max_page_size = 1000


class RootServerViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = models.RootServer.objects.all()
    serializer_class = serializers.RootServerSerializer


class ServiceBodyViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = models.ServiceBody.objects.all()
    serializer_class = serializers.ServiceBodySerializer
    pagination_class = StandardResultsSetPagination


class FormatViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = models.Format.objects.all()
    serializer_class = serializers.FormatSerializer
    pagination_class = StandardResultsSetPagination


class MeetingViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = models.Meeting.objects.all().order_by('pk')
    serializer_class = serializers.MeetingSerializer
    pagination_class = StandardResultsSetPagination
