# Generated by Django 2.0.2 on 2018-10-13 15:02

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0005_auto_20180521_2349'),
    ]

    operations = [
        migrations.AddField(
            model_name='rootserver',
            name='name',
            field=models.CharField(max_length=255, null=True),
        ),
        migrations.AddField(
            model_name='rootserver',
            name='server_info',
            field=models.TextField(null=True),
        ),
    ]
