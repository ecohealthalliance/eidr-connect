# This script downloads India MoH ISDP Weekly Outbreak Reports, extracts
# tabular data from them, then uses it to create EIDR-Connect incidents.
# pdftohtml and wget must be installed
from __future__ import print_function
import re
import requests
import datetime
import subprocess
import pandas as pd
import os
import pymongo
import functools
try:
    from functools import lru_cache
except ImportError:
    from backports.functools_lru_cache import lru_cache

GRITS_URL = os.environ.get("GRITS_URL", "https://grits.eha.io")


def clean(s):
    return re.sub(r"\s+", " ", s).strip()


@lru_cache()
def lookup_geoname(name):
    resp = requests.get(GRITS_URL + "/api/geoname_lookup/api/lookup", params={
        "q": name
    })
    result = resp.json()["hits"][0]["_source"]
    del result["alternateNames"]
    del result["rawNames"]
    del result["asciiName"]
    del result["cc2"]
    del result["elevation"]
    del result["dem"]
    del result["timezone"]
    del result["modificationDate"]
    return result


@lru_cache()
def lookup_disease(name):
    resp = requests.get(GRITS_URL + "/api/v1/disease_ontology/lookup", params={
        "q": name
    })
    result = resp.json()
    first_result = next(iter(result["result"]), None)
    if first_result:
        return {
            "id": first_result["id"],
            "text": first_result["label"]
        }

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("download_dir")
    args = parser.parse_args()
    
    db = pymongo.MongoClient(os.environ["MONGO_HOST"])["eidr-connect"]
    
    feed_url = "http://idsp.nic.in/index4.php?lang=1&level=0&linkid=406&lid=3689"
    feed = db.feeds.find_one({"url": feed_url})
    if not (feed and datetime.datetime.now() - datetime.timedelta(10) < feed["addedDate"]):
        # Only reimport the data if it hasn't been updated in at least 10 days
        db.feeds.update_one({
            "url": feed_url
        }, {
            "$set": {
                "title": "India Ministry of Health IDSP Weekly Outbreaks",
                "addedDate": datetime.datetime.now(),
                "structuredData": True
            }
        }, upsert=True)
    
    
        # Reports all appear to use a 6 day long week.
        week_periods = pd.date_range("2018-01-01", datetime.datetime.now(), freq="6D", closed="left")
        for week_num, period in enumerate(week_periods):
            week_num = week_num + 1
            filename = "%02d%s.pdf" % (week_num, period.to_period().start_time.year)
            print("Processing:" + filename)
            url = "http://idsp.nic.in/WriteReadData/l892s/" + filename
            filepath = os.path.join(args.download_dir, filename)
            if not os.path.exists(filepath):
                result = subprocess.call(["wget", url, "-O", filepath])
                if result != 0:
                    break
                pdftotext_result = subprocess.call(["pdftotext", filepath])
                if pdftotext_result != 0:
                    print("Removing invalid pdf: " + filepath)
                    os.remove(filepath)
                    continue
            textfilepath = filepath.replace(".pdf", ".txt")
            if not os.path.exists(textfilepath):
                print("Could not find file: " + textfilepath)
                continue
            with open(textfilepath) as f:
                regex = re.compile(
                    r"(\w{2,}\/\w{2,}\/\d{4}/\d+/\d+)\s+"
                    r"(?P<state>\S(.+\n)+)\s+"
                    r"(?P<district>\S(.+\n)+)\s+"
                    r"(?P<disease>\S(.+\n)+)\s+"
                    r"(?P<cases>\d+)\s+"
                    r"(?P<deaths>\d+)\s+"
                    r"(?P<start>\S(.+\n)+)\s+"
                    r"(?P<reported>\d+\-\d+\-\d+)\s+"
                    r"(?P<status>\S(.+\n)+)\s+")
                for match in regex.finditer(f.read()):
                    groups = match.groupdict()
                    try:
                        end_date = datetime.datetime.strptime(
                            clean(groups["reported"]), "%d-%m-%y")
                    except ValueError:
                        print("Invalid date:", groups["reported"])
                        continue
                    try:
                        start_date = datetime.datetime.strptime(
                            clean(groups["start"]), "%d-%m-%y")
                    except ValueError:
                        print("Invalid date:", groups["start"])
                        continue
                    location_name = clean(groups["state"]) + ", " + clean(groups["district"])
                    geoname = lookup_geoname(location_name)
                    if not geoname: continue
                    resolved_disease = lookup_disease(clean(groups["disease"]))
                    if not resolved_disease: continue
                    for count_type in ["cases", "deaths"]:
                        db.counts.insert_one({
                            "sourceFeed": str(feed["_id"]),
                            "constraining": True,
                            "dateRange": {
                                "type": "precise",
                                "start": start_date,
                                "end": end_date
                            },
                            "locations": [geoname],
                            "type": "caseCount" if count_type == "cases" else "deathCount",
                            count_type: int(groups[count_type]),
                            "resolvedDisease": resolved_disease,
                            "species": {
                                "id": "tsn:180092",
                                "text": "Homo sapiens"
                            },
                            "addedDate": datetime.datetime.now()
                        })
