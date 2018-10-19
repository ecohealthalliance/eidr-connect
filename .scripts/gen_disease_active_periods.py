from __future__ import print_function
import pandas as pd
import json

df = pd.read_csv("curated-disease-durations.csv")
disease_uri_to_active_period = {}
for idx, row in df.iterrows():
    if not pd.isnull(row['uri']):
        active_period = row['aproximate days of contagiousness']
        if pd.isnull(active_period): continue
        disease_uri_to_active_period[row['uri']] = int(active_period)

with open("diseaseURIToActivePeriod.json", "w") as f:
    json.dump(disease_uri_to_active_period, f, indent=2)
