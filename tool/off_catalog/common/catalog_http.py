"""Bounded, cached public-catalog reads with per-host pacing and robots rules."""

from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import time
from urllib.parse import urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener
from urllib.error import HTTPError
from urllib.robotparser import RobotFileParser

USER_AGENT = 'DiabeatthisCatalogResearch/1.0 (https://diabeatthis.pl)'


class AllowedRedirect(HTTPRedirectHandler):
    def __init__(self, allowed):
        self.allowed = allowed

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not self.allowed(newurl):
            raise ValueError('Redirect outside configured catalog host')
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class CatalogHttp:
    def __init__(self, base_url, directory, delay=0.5, refresh=False):
        self.base_url = base_url.rstrip('/')
        self.host = urlparse(base_url).hostname
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True)
        self.delay, self.refresh, self.last_request = delay, refresh, 0.0
        self.opener = build_opener(AllowedRedirect(self.allowed))
        self.requests, self.cache_hits = 0, 0
        self.robot = RobotFileParser()
        self.robot.set_url(self.base_url + '/robots.txt')
        text = self._read(self.base_url + '/robots.txt').decode('utf-8', 'replace')
        if '<html' in text.lower() or '<!doctype' in text.lower():
            raise ValueError('robots.txt is HTML, source needs connector review')
        self.robot.parse(text.splitlines())
        self.delay = max(delay, self.robot.crawl_delay(USER_AGENT) or 0)

    def allowed(self, url):
        parsed = urlparse(url)
        return parsed.scheme == 'https' and parsed.hostname in (self.host, 'www.' + self.host) and not parsed.username and not parsed.password and parsed.port in (None, 443)

    def _read(self, url):
        if not self.allowed(url):
            raise ValueError('URL outside configured catalog host')
        key = hashlib.sha256(url.encode()).hexdigest()
        body, metadata = self.directory / (key + '.body'), self.directory / (key + '.json')
        if body.exists() and metadata.exists() and not self.refresh:
            raw = body.read_bytes()
            if hashlib.sha256(raw).hexdigest() == json.loads(metadata.read_text())['sha256']:
                self.cache_hits += 1
                return raw
        time.sleep(max(0, self.delay - (time.monotonic() - self.last_request)))
        self.last_request = time.monotonic()
        self.requests += 1
        try:
            with self.opener.open(Request(url, headers={'User-Agent': USER_AGENT}), timeout=25) as response:
                raw = response.read(12 * 1024 * 1024 + 1)
                if len(raw) > 12 * 1024 * 1024:
                    raise ValueError('Catalog response exceeds size bound')
                info = {'url': url, 'resolved_url': response.url, 'fetched_at': datetime.now(timezone.utc).isoformat(),
                        'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw),
                        'etag': response.headers.get('ETag'), 'last_modified': response.headers.get('Last-Modified')}
        except HTTPError as error:
            if error.code == 404 and url.endswith('/robots.txt'):
                raw, info = b'', {'url': url, 'status': 404, 'sha256': hashlib.sha256(b'').hexdigest()}
            else:
                raise
        temporary = body.with_suffix('.partial')
        temporary.write_bytes(raw)
        temporary.replace(body)
        metadata.write_text(json.dumps(info, indent=2) + '\n')
        return raw

    def read(self, url):
        if not self.allowed(url) or not self.robot.can_fetch(USER_AGENT, url):
            raise ValueError('URL not allowed by catalog policy or robots.txt')
        return self._read(url)
