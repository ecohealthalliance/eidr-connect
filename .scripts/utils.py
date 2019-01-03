import re
import requests
import os
import functools
import json
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
    result = json.loads(resp.text)["hits"][0]["_source"]
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
    if len(name) == 0:
        return None
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