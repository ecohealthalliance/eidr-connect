import json
import pandas as pd
import requests
from StringIO import StringIO
import re

continent_names = {
    "AF": "Africa",
    "AS": "Asia",
    "EU": "Europe",
    "NA": "North America",
    "OC": "Oceania",
    "SA": "South America",
    "AN": "Antarctica",
}
continent_geonameids = {
    "AF": "6255146",
    "AS": "6255147",
    "EU": "6255148",
    "NA": "6255149",
    "OC": "6255151",
    "SA": "6255150",
    "AN": "6255152",
}
response = requests.get("http://download.geonames.org/export/dump/countryInfo.txt")
country_table = pd.read_csv(StringIO(re.split(r'^#[^\n]*$', response.content, flags=re.M)[-1]),
                            sep='\t',
                            header=None,
                            names=[
                                "ISO",
                                "ISO3",
                                "ISO-Numeric",
                                "fips",
                                "Country",
                                "Capital",
                                "Area(in sq km)",
                                "Population",
                                "Continent",
                                "tld",
                                "CurrencyCode",
                                "CurrencyName",
                                "Phone",
                                "Postal Code Format",
                                "Postal Code Regex",
                                "Languages",
                                "geonameid",
                                "neighbours",
                                "EquivalentFipsCode",
                            ],
                            # The NA ISO code for Namibia will be parsed as an NA value without this.
                            keep_default_na=False)
regionToCountries = {}
for group, rows in country_table.groupby("Continent"):
    regionToCountries[continent_geonameids[group]] = {
        "name": continent_names[group],
        "continentCode": group,
        "countryISOs":  list(rows.ISO.values)
    }

regionToCountries["7729885"] = {
    "name": "Western Africa",
    "countryISOs": [
        "BF",
        "BJ",
        "CI",
        "CV",
        "GH",
        "GM",
        "GN",
        "GW",
        "LR",
        "ML",
        "MR",
        "NE",
        "NG",
        "SH",
        "SL",
        "SN",
        "TG",
    ]
}

with open("regionToCountries.json", "w") as f:
    json.dump(regionToCountries, f, indent=2)

countryISOToGeoname = {
    group: {
        "id": str(rows.geonameid.values[0]),
        "countryName": rows.Country.values[0],
        "countryCode": rows.ISO.values[0],
        "featureCode": "PCL*",
        "name": rows.Country.values[0],
    }
    for group, rows in country_table.groupby("ISO") }

with open("countryISOToGeoname.json", "w") as f:
    json.dump(countryISOToGeoname, f, indent=2)
