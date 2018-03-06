import json
import logging
import requests
import requests.exceptions
import time
from django.core.management.base import BaseCommand
from django.db import transaction
from urllib.parse import urljoin
from ...models import Format, ImportProblem, Meeting, RootServer, ServiceBody


class Command(BaseCommand):
    help = 'Updates the meetings database from root servers'

    def handle(self, *args, **options):
        logger = logging.getLogger('django')
        logger.info('starting daemon')

        while True:
            logger.info('retrieving root servers')
            url = 'https://raw.githubusercontent.com/LittleGreenViper/BMLTTally/master/rootServerList.json'
            try:
                root_server_urls = [rs['rootURL'] for rs in json.loads(self.request(url))]
            except Exception as e:
                logger.error('Error retrieving root server list: {}'.format(str(e)))
            else:
                for url in root_server_urls:
                    url = url if url.endswith('/') else url + '/'
                    logger.info('importing root server {}'.format(url))
                    try:
                        root = RootServer.objects.get_or_create(url=url)[0]
                        ImportProblem.objects.filter(root_server=root).delete()
                        with transaction.atomic():
                            logger.info('importing service bodies')
                            self.update_service_bodies(root)
                            logger.info('importing formats')
                            self.update_formats(root)
                            logger.info('importing meetings')
                            self.update_meetings(root)
                    except Exception as e:
                        logger.error('Error updating root server: {}'.format(str(e)))
            logger.info('sleeping')
            time.sleep(3600)

    def request(self, url):
        headers = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0'}
        response = requests.get(url, headers=headers)
        if response.status_code != 200:
            raise Exception('Unexpected status code from root server')
        return response.content

    def update_service_bodies(self, root):
        url = urljoin(root.url, 'client_interface/json/?switcher=GetServiceBodies')
        service_bodies = json.loads(self.request(url))
        ServiceBody.import_from_bmlt_objects(root, service_bodies)

    def update_formats(self, root):
        url = urljoin(root.url, 'client_interface/json/?switcher=GetFormats')
        formats = json.loads(self.request(url))
        Format.import_from_bmlt_objects(root, formats)

    def update_meetings(self, root):
        url = urljoin(root.url, 'client_interface/json/?switcher=GetSearchResults')
        meetings = json.loads(self.request(url))

        # Delete meetings that no longer exist
        meeting_ids = [int(m['id_bigint']) for m in meetings]
        Meeting.objects.filter(root_server=root).exclude(source_id__in=meeting_ids).delete()

        # Import the rest
        Meeting.import_from_bmlt_objects(root, meetings)