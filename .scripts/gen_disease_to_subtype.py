from __future__ import absolute_import
from __future__ import print_function
import rdflib
import re
import json


DISEASE_ONTOLOGY_URL = "http://purl.obolibrary.org/obo/doid.owl"

disease_ontology = rdflib.Graph()
disease_ontology.parse(DISEASE_ONTOLOGY_URL, format="xml")

disease_labels = disease_ontology.query("""
SELECT ?entity ?parent
WHERE {
    # only include diseases by infectious agent
    ?parent rdfs:subClassOf* obo:DOID_0050117 .
    ?entity rdfs:subClassOf* ?parent
}
""")
disease_to_subtypes = {}
for entity, parent in disease_labels:
    entity_uri = str(entity)
    parent_uri = str(parent)
    if entity_uri == parent_uri: continue
    if entity_uri.startswith("http://") and parent_uri.startswith("http://"):
        disease_to_subtypes[parent_uri] = disease_to_subtypes.get(parent_uri, []) + [entity_uri]

with open("diseaseToSubtypes.json", "w") as f:
    json.dump(disease_to_subtypes, f, indent=2)
