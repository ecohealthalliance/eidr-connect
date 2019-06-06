from __future__ import print_function
import re
import time
import requests
import datetime
import os
import pymongo
from utils import clean, clean_disease_name, lookup_geoname, lookup_disease
import six
from bson.objectid import ObjectId
import sys

if __name__ == "__main__":
    db = pymongo.MongoClient(os.environ["MONGO_HOST"])["eidr-connect"]
    feed_url = "https://epiarchive.bsvgateway.org"
    db.stagingIncidents.drop()
    feed = db.feeds.find_one({"url": feed_url})
    if not feed:
        db.feeds.insert({
            "_id": six.text_type(ObjectId()),
            "title": "EpiArchive",
            "structuredData": True,
            "url": feed_url
        })
        feed = db.feeds.find_one({"url": feed_url})
    if datetime.datetime.now() - datetime.timedelta(0) < feed.get("addedDate", datetime.datetime(2000,1,1)):
        # Only reimport the data if it hasn't been updated in at least 10 days
        sys.exit()
    # TODO: Get subregions for each country and request diseases w/ that??
    resp = requests.get("https://epiarchive.bsvgateway.org/api/country-diseases/", params={
        'limit': 2000
    })
    country_diseases = resp.json()
    for item in country_diseases['results']:
        # print(item['country_name'], item['disease_name'])
        geoname = lookup_geoname(item['country_name'])
        if not geoname:
            print("Location not found:" + item['country_name'])
            continue
        disease_name = clean_disease_name(item['disease_name'].split('(')[0])
        resolved_disease = lookup_disease(disease_name)
        if not resolved_disease:
            print("Disease not found: " + item['disease_name'] + " [" + disease_name + "]")
            continue
        item_resp = requests.get('https://epiarchive.bsvgateway.org/api/case-count-by-interval', params={
            'region_id': item['country_id'],
            'disease': item['disease'],
            'start': '01/01/1980',
            'end': '01/01/2100'})
        for i2 in item_resp.json():
            if i2['cases'] is None:
                continue
            start_date = datetime.datetime.strptime(i2['interval__start_time'], "%Y-%m-%dT%H:%M:%SZ")
            end_date = datetime.datetime.strptime(i2['interval__end_time'], "%Y-%m-%dT%H:%M:%SZ")
            # Round end_date up to start of next day
            end_date = datetime.datetime(end_date.year, end_date.month, end_date.day) + datetime.timedelta(1)
            db.stagingIncidents.insert_one({
                "_id": six.text_type(ObjectId()),
                "sourceFeed": feed["_id"],
                "constraining": True,
                "dateRange": {
                    "type": "precise",
                    "start": start_date,
                    "end": end_date
                },
                "locations": [geoname],
                "type": "caseCount",
                "cases": i2['cases'],
                "resolvedDisease": resolved_disease,
                "species": {
                    "id": "tsn:180092",
                    "text": "Homo sapiens"
                },
                "addedDate": datetime.datetime.now()
            })
        time.sleep(5)
    if db.stagingIncidents.count() > 0:
        db.counts.delete_many({"sourceFeed": feed["_id"]})
        for doc in db.stagingIncidents.find():
            db.counts.insert(doc)
        db.stagingIncidents.drop()
        db.feeds.update_one({
            "url": feed_url
        }, {
            "$set": {
                "addedDate": datetime.datetime.now()
            }
        })
    else:
        print("The staging database is empty. The import has failed.")
