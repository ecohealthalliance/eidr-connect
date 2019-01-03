from __future__ import print_function
import re
import time
import requests
import datetime
import os
import pymongo
from utils import clean, lookup_geoname, lookup_disease


if __name__ == "__main__":
    db = pymongo.MongoClient(os.environ["MONGO_HOST"])["eidr-connect"]
    feed_url = "https://epiarchive.bsvgateway.org"
    db.stagingIncidents.drop()
    feed = db.feeds.find_one({"url": feed_url})
    if not (feed and datetime.datetime.now() - datetime.timedelta(10) < feed["addedDate"]):
        # Only reimport the data if it hasn't been updated in at least 10 days
        db.feeds.update_one({
            "url": feed_url
        }, {
            "$set": {
                "title": "EpiArchive",
                "addedDate": datetime.datetime.now(),
                "structuredData": True
            }
        }, upsert=True)
    feed = db.feeds.find_one({"url": feed_url})
    assert len(str(feed['_id'])) > 5
    # TODO: Get subregions for each country and request diseases w/ that??
    resp = requests.get("https://epiarchive.bsvgateway.org/api/country-diseases/")
    country_diseases = resp.json()
    for item in country_diseases:
        #print(item['country_name'], item['disease_name'])
        geoname = lookup_geoname(item['country_name'])
        if not geoname:
            print("Location not found:" + item['country_name'])
            continue
        disease_name = clean(item['disease_name'].split('(')[0])
        resolved_disease = lookup_disease(disease_name)
        if not resolved_disease:
            if disease_name.lower() == "cchf":
                resolved_disease = {
                    "id": "http://purl.obolibrary.org/obo/DOID_12287",
                    "label": "Crimean-Congo hemorrhagic fever"}
            else:
                print("Disease not found: " + item['disease_name'] + " [" + disease_name + "]")
                continue
        item_resp = requests.get('https://epiarchive.bsvgateway.org/api/case-count-by-interval', params={
            'region_id': item['country_id'],
            'disease': item['disease'],
            'start': '01/01/1980',
            'end': '01/01/2100'})
        for i2 in item_resp.json():
            start_date = datetime.datetime.strptime(i2['interval__start_time'], "%Y-%m-%dT%H:%M:%SZ")
            end_date = datetime.datetime.strptime(i2['interval__end_time'], "%Y-%m-%dT%H:%M:%SZ")
            # Round end_date up to start of next day
            end_date = datetime.datetime(end_date.year, end_date.month, end_date.day) + datetime.timedelta(1)
            db.stagingIncidents.insert_one({
                "sourceFeed": str(feed["_id"]),
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
    # TODO: create staging db and move?
    # Avoid loosing data if reimport fails.
    # or limit time range to after last incident of feed? Or prior added date?
    # Recreating everything is more robust to past data changes though.
    db.counts.delete_many({"sourceFeed": str(feed["_id"])})
    for doc in db.stagingIncidents.find():
        db.counts.insert(doc)
    db.stagingIncidents.drop()
