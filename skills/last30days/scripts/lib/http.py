"""HTTP utilities for last30days skill (stdlib only)."""

import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
from typing import Any, Dict, Optional, Tuple
from urllib.parse import urlencode

DEFAULT_TIMEOUT = 30
DEBUG = os.environ.get("LAST30DAYS_DEBUG", "").lower() in ("1", "true", "yes")


def log(msg: str):
    """Log debug message to stderr."""
    if DEBUG:
        sys.stderr.write(f"[DEBUG] {msg}\n")
        sys.stderr.flush()
MAX_RETRIES = 5
RETRY_DELAY = 2.0
USER_AGENT = "last30days-skill/2.1 (Assistant Skill)"


class HTTPError(Exception):
    """HTTP request error with status code."""
    def __init__(self, message: str, status_code: Optional[int] = None, body: Optional[str] = None, is_block: bool = False):
        super().__init__(message)
        self.status_code = status_code
        self.body = body
        self.is_block = is_block


def _get_ssl_context(disable_alpn: bool = False) -> ssl.SSLContext:
    """Create a resilient SSL context.
    
    Loads CA certs from SSL_CERT_FILE if available.
    Optionally disables ALPN to avoid issues with some proxies.
    """
    context = ssl.create_default_context()
    
    cert_file = os.environ.get('SSL_CERT_FILE')
    if cert_file and os.path.exists(cert_file):
        try:
            context.load_verify_locations(cafile=cert_file)
        except Exception as e:
            log(f"Failed to load SSL_CERT_FILE {cert_file}: {e}")
            
    if disable_alpn:
        context.set_alpn_protocols([])
        
    return context


def _detect_proxy_block(e: Exception) -> Tuple[bool, str]:
    """Check if an error indicates a proxy block (e.g. Cisco Umbrella)."""
    msg = str(e).lower()
    
    # Check for Cisco Umbrella patterns
    if "sslv3_alert_handshake_failure" in msg or "handshake_failure" in msg:
        # Handshake failure on domains like polymarket is often a proxy block
        return True, "SSL Handshake Failure (Possible Proxy Block)"
    
    if "forbidden" in msg and "cisco" in msg:
        return True, "Blocked by Cisco Umbrella"
        
    return False, ""


def request(
    method: str,
    url: str,
    headers: Optional[Dict[str, str]] = None,
    json_data: Optional[Dict[str, Any]] = None,
    timeout: int = DEFAULT_TIMEOUT,
    retries: int = MAX_RETRIES,
) -> Dict[str, Any]:
    """Make an HTTP request and return JSON response.

    Args:
        method: HTTP method (GET, POST, etc.)
        url: Request URL
        headers: Optional headers dict
        json_data: Optional JSON body (for POST)
        timeout: Request timeout in seconds
        retries: Number of retries on failure

    Returns:
        Parsed JSON response

    Raises:
        HTTPError: On request failure
    """
    headers = headers or {}
    headers.setdefault("User-Agent", USER_AGENT)

    data = None
    if json_data is not None:
        data = json.dumps(json_data).encode('utf-8')
        headers.setdefault("Content-Type", "application/json")

    req = urllib.request.Request(url, data=data, headers=headers, method=method)

    log(f"{method} {url}")
    if json_data:
        log(f"Payload keys: {list(json_data.keys())}")

    last_error = None
    context = _get_ssl_context()
    
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=timeout, context=context) as response:
                body = response.read().decode('utf-8')
                log(f"Response: {response.status} ({len(body)} bytes)")
                return json.loads(body) if body else {}
        except urllib.error.HTTPError as e:
            body = None
            try:
                body = e.read().decode('utf-8')
            except:
                pass
            
            is_block, block_msg = _detect_proxy_block(e)
            if not is_block and body:
                if "Cisco Umbrella" in body or "block.sse.cisco.com" in body:
                    is_block = True
                    block_msg = "Blocked by Cisco Umbrella"
            
            log(f"HTTP Error {e.code}: {e.reason}")
            if body:
                log(f"Error body: {body[:500]}")
            
            last_error = HTTPError(block_msg or f"HTTP {e.code}: {e.reason}", e.code, body, is_block=is_block)

            # Don't retry client errors (4xx) except rate limits
            if (400 <= e.code < 500 and e.code != 429) or is_block:
                raise last_error

            if attempt < retries - 1:
                # ... same retry logic ...
                if e.code == 429:
                    retry_after = e.headers.get("Retry-After") if hasattr(e, 'headers') else None
                    if retry_after:
                        try:
                            delay = float(retry_after)
                        except ValueError:
                            delay = RETRY_DELAY * (2 ** attempt) + 1
                    else:
                        delay = RETRY_DELAY * (2 ** attempt) + 1
                    log(f"Rate limited (429). Waiting {delay:.1f}s before retry {attempt + 2}/{retries}")
                else:
                    delay = RETRY_DELAY * (2 ** attempt)
                time.sleep(delay)
        except (urllib.error.URLError, ssl.SSLError) as e:
            log(f"SSL/URL Error: {e}")
            is_block, block_msg = _detect_proxy_block(e)
            
            # If we hit a handshake failure, try once more without ALPN
            if "handshake_failure" in str(e).lower() and not context.set_alpn_protocols([]) and attempt == 0:
                log("Retrying with ALPN disabled...")
                context = _get_ssl_context(disable_alpn=True)
                continue
                
            last_error = HTTPError(block_msg or f"SSL/URL Error: {e}", is_block=is_block)
            if is_block:
                raise last_error
                
            if attempt < retries - 1:
                time.sleep(RETRY_DELAY * (attempt + 1))
        except json.JSONDecodeError as e:
            log(f"JSON decode error: {e}")
            last_error = HTTPError(f"Invalid JSON response: {e}")
            raise last_error
        except (OSError, TimeoutError, ConnectionResetError) as e:
            log(f"Connection error: {type(e).__name__}: {e}")
            last_error = HTTPError(f"Connection error: {type(e).__name__}: {e}")
            if attempt < retries - 1:
                time.sleep(RETRY_DELAY * (attempt + 1))

    if last_error:
        raise last_error
    raise HTTPError("Request failed with no error details")


def get(url: str, headers: Optional[Dict[str, str]] = None, **kwargs) -> Dict[str, Any]:
    """Make a GET request."""
    return request("GET", url, headers=headers, **kwargs)


def post(url: str, json_data: Dict[str, Any], headers: Optional[Dict[str, str]] = None, **kwargs) -> Dict[str, Any]:
    """Make a POST request with JSON body."""
    return request("POST", url, headers=headers, json_data=json_data, **kwargs)


def get_reddit_json(path: str, timeout: int = DEFAULT_TIMEOUT, retries: int = MAX_RETRIES) -> Dict[str, Any]:
    """Fetch Reddit thread JSON.

    Args:
        path: Reddit path (e.g., /r/subreddit/comments/id/title)
        timeout: HTTP timeout per attempt in seconds
        retries: Number of retries on failure

    Returns:
        Parsed JSON response
    """
    # Ensure path starts with /
    if not path.startswith('/'):
        path = '/' + path

    # Remove trailing slash and add .json
    path = path.rstrip('/')
    if not path.endswith('.json'):
        path = path + '.json'

    url = f"https://www.reddit.com{path}?raw_json=1"

    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
    }

    return get(url, headers=headers, timeout=timeout, retries=retries)
