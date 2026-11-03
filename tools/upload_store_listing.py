"""Uploads the Play Store listing in store/ (text, video link, feature graphic, phone screenshots).

Uses the Google Play Developer API through one "edit": nothing goes live unless every step works,
and the committed edit then goes through Google's normal listing review.

  python3 tools/upload_store_listing.py --dry-run            # show what would be uploaded
  PLAY_SERVICE_ACCOUNT_JSON="$(cat key.json)" python3 tools/upload_store_listing.py

Needs google-api-python-client and google-auth (pip install google-api-python-client google-auth).
"""
import argparse
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), '..')
STORE = os.path.join(ROOT, 'store')
PACKAGE = 'ca.kallistesoft.neon_breaker'

# Play locale -> (listing file, screenshot folder, feature graphic)
LOCALES = {
    'en-US': ('listing-en-US.md', 'screenshots/en', 'feature-graphic-en.png'),
    'fr-FR': ('listing-fr.md', 'screenshots/fr', 'feature-graphic-fr.png'),
}
LIMITS = {'title': 30, 'shortDescription': 80, 'fullDescription': 4000}


def read_listing(path):
    """The listing files have three '# ' sections: title, short description, full description."""
    parts = [p.strip() for p in re.split(r'^# .*$', open(path, encoding='utf-8').read(), flags=re.M)[1:]]
    if len(parts) != 3:
        raise SystemExit(f'{path}: expected 3 sections (title, short, full), found {len(parts)}')
    listing = dict(zip(('title', 'shortDescription', 'fullDescription'), parts))
    for key, limit in LIMITS.items():
        if len(listing[key]) > limit:
            raise SystemExit(f'{path}: {key} is {len(listing[key])} characters, Play allows {limit}')
    return listing


def plan():
    video = open(os.path.join(STORE, 'video-url.txt'), encoding='utf-8').read().strip()
    out = {}
    for locale, (listing_file, shots_dir, feature) in LOCALES.items():
        shots = sorted(f for f in os.listdir(os.path.join(STORE, shots_dir)) if f.endswith('.png'))
        if not 2 <= len(shots) <= 8:
            raise SystemExit(f'{shots_dir}: Play needs 2 to 8 phone screenshots, found {len(shots)}')
        out[locale] = {
            'listing': {**read_listing(os.path.join(STORE, listing_file)), 'video': video},
            'featureGraphic': os.path.join(STORE, feature),
            'phoneScreenshots': [os.path.join(STORE, shots_dir, f) for f in shots],
        }
    return out


def upload(work):
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload

    key = os.environ.get('PLAY_SERVICE_ACCOUNT_JSON')
    if not key:
        raise SystemExit('PLAY_SERVICE_ACCOUNT_JSON is not set')
    creds = service_account.Credentials.from_service_account_info(
        json.loads(key), scopes=['https://www.googleapis.com/auth/androidpublisher'])
    edits = build('androidpublisher', 'v3', credentials=creds, cache_discovery=False).edits()

    edit = edits.insert(packageName=PACKAGE, body={}).execute()['id']
    try:
        for locale, item in work.items():
            print(f'{locale}: listing text and video')
            edits.listings().update(packageName=PACKAGE, editId=edit, language=locale, body=item['listing']).execute()
            for image_type, files in (('featureGraphic', [item['featureGraphic']]), ('phoneScreenshots', item['phoneScreenshots'])):
                print(f'{locale}: {image_type} ({len(files)})')
                edits.images().deleteall(packageName=PACKAGE, editId=edit, language=locale, imageType=image_type).execute()
                for f in files:
                    edits.images().upload(packageName=PACKAGE, editId=edit, language=locale, imageType=image_type,
                                          media_body=MediaFileUpload(f, mimetype='image/png')).execute()
        edits.commit(packageName=PACKAGE, editId=edit).execute()
    except Exception:
        edits.delete(packageName=PACKAGE, editId=edit).execute()
        raise
    print('Committed: the listing is now in Google review.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true', help='check the files and print the plan, upload nothing')
    args = parser.parse_args()
    work = plan()
    for locale, item in work.items():
        lst = item['listing']
        print(f"{locale}: '{lst['title']}', short {len(lst['shortDescription'])}/80, full {len(lst['fullDescription'])}/4000, "
              f"video {lst['video']}, {len(item['phoneScreenshots'])} screenshots")
    if not args.dry_run:
        upload(work)


if __name__ == '__main__':
    sys.exit(main())
