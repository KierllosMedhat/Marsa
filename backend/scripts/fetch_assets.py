import urllib.request
import os

os.makedirs('web/public/assets', exist_ok=True)

headers = {'User-Agent': 'Mozilla/5.0'}
urls = {
    'logo.jpg': 'https://ugc.production.linktr.ee/97e61afc-b71f-46b1-85d5-ce6141c8de97_1001161184.jpeg',
    'fb_profile.jpg': 'https://ugc.production.linktr.ee/29283957-76f1-46e8-bfb2-b2522f2d2c00_825266921-10243023325346428-2398011187336741139-n.jpeg'
}

for name, url in urls.items():
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as resp, open(f'web/public/assets/{name}', 'wb') as f:
            f.write(resp.read())
        print(f"Downloaded {name}, size: {os.path.getsize(f'web/public/assets/{name}')} bytes")
    except Exception as e:
        print(f"Failed {name}: {e}")
