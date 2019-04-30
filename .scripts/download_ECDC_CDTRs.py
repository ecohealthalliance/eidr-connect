# pdftohtml and wget must be installed
from __future__ import print_function
import re
import requests
import datetime
import subprocess
import os
import pymongo
from bson.objectid import ObjectId
from bs4 import BeautifulSoup

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("download_dir")
    args = parser.parse_args()
    db = pymongo.MongoClient(os.environ["MONGO_HOST"])["eidr-connect"]
    FEED_URL = "https://ecdc.europa.eu/en/publications-data"
    def ECDC_data_generator():
        page = 0
        while True:
            response = requests.get(FEED_URL, params={
                "s": "CDTR",
                "sort_by": "field_ct_publication_date",
                "sort_order": "DESC",
                "f[0]": "publication_series:1505",
                "page": page
            })
            soup = BeautifulSoup(response.text)
            articles = soup.select('article')
            if len(articles) == 0:
                break
            for item in articles:
                title = item.select_one('.ct__title').text.strip()
                url = item.select('.media-body a')[0].attrs['href']
                date = datetime.datetime.strptime(item.select_one('time').text, "%d %b %Y")
                yield title, url, date
            page += 1
    item_iter = ECDC_data_generator()
    title, url, date = next(item_iter, (None, None, None,))
    if url:
        feed = db.feeds.find_one({ "url": FEED_URL })
        if feed:
            feed_id = feed['_id']
        else:
            feed_id = str(ObjectId())
            db.feeds.insert({
                "_id": feed_id,
                "url": FEED_URL,
                "title": 'ECDC COMMUNICABLE DISEASE THREATS REPORTS',
                "addedDate": datetime.datetime.now()
            })
        while url:
            print("Processing: " + url)
            base, filename = os.path.split(url)
            filepath = os.path.join(args.download_dir, filename)
            textfilepath = filepath.replace(".pdf", ".txt")
            if not os.path.exists(textfilepath):
                result = subprocess.call([
                    "wget", url,
                    "-O", filepath])
                if result != 0:
                    break
                pdftotext_result = subprocess.call([
                    "pdftotext",
                    "-x", '40',
                    "-y", '50',
                    "-H", '730',
                    "-W", '520',
                    "-layout",
                    filepath])
                if pdftotext_result != 0:
                    print("Removing invalid pdf: " + filepath)
                    os.remove(filepath)
                    break
            if not os.path.exists(textfilepath):
                print("Could not find file: " + textfilepath)
                break
            with open(textfilepath) as f:
                text = f.read()
                summary_section = "\n\n\n" + text.split('II. Detailed reports')[0]
                split_subsections = re.split(r"((?:.{3,}\n){1,3})Opening date", summary_section)[1:]
                for section_title, section in zip(split_subsections[0::2], split_subsections[1::2]):
                    section_title = section_title.strip()
                    section_title = section_title.replace('±', ' ')
                    section_title = re.sub("\s{1,}", " ", section_title)
                    full_title = str(title) + ': ' + section_title
                    content = section_title + '\nOpening date' + section.strip()
                    existing_article = db.articles.find_one({
                        "title": full_title,
                        "feedId": feed_id
                    })
                    if not existing_article:
                        article_data = {
                            "_id": str(ObjectId()),
                            "content": content,
                            "addedDate": datetime.datetime.now(),
                            "publishDate": date,
                            "publishDateTZ": "UTC",
                            "title": full_title,
                            "reviewed": False,
                            "feedId": feed_id
                        }
                        db.articles.insert(article_data)
            title, url, date = next(item_iter, None)
