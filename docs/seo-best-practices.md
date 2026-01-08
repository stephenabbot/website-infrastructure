# SEO Best Practices Implementation

## Canonical Domain Strategy

### Why Canonical Domains Matter

Search engines treat `example.com` and `www.example.com` as completely separate websites. This creates several critical SEO problems:

1. **Split Authority**: Your domain authority and PageRank get divided between two identical sites
2. **Duplicate Content Penalties**: Google penalizes sites with identical content across multiple URLs
3. **Diluted Analytics**: Traffic, conversions, and user behavior data gets fragmented
4. **Inconsistent User Experience**: Users may bookmark different versions of the same page
5. **Wasted Crawl Budget**: Search engines waste time crawling duplicate content

### The Solution: Non-WWW Canonical Implementation

This infrastructure implements **non-WWW canonical domains** as the industry best practice for modern websites:

#### Why Non-WWW?

- **Shorter URLs**: Cleaner, more memorable domain names
- **Modern Standard**: Most new websites use apex domains as canonical
- **Mobile Friendly**: Shorter URLs work better on mobile devices
- **Brand Consistency**: Matches modern branding expectations

#### Technical Implementation

**CloudFront Function (Edge-Level Redirect)**

```javascript
// Executes at CloudFront edge locations worldwide
if (host.startsWith('www.')) {
    var canonicalHost = host.replace('www.', '');
    return {
        statusCode: 301,                    // Permanent redirect
        statusDescription: 'Moved Permanently',
        headers: {
            'location': { value: 'https://' + canonicalHost + uri }
        }
    };
}
```

**DNS Configuration**

```
denverbytes.com.        A       13.226.251.129  (CloudFront IPs)
www.denverbytes.com.    CNAME   denverbytes.com.
```

**SSL Certificate Coverage**

- Primary: `denverbytes.com`
- Subject Alternative Name: `www.denverbytes.com`

### Typo Domain Protection

#### Brand Protection Strategy

This implementation includes protection against common typos that could confuse users or be exploited by competitors:

**Protected Typo Domains**

- `denverbites.com` → `denverbytes.com` (common phonetic spelling)
- `www.denverbites.com` → `denverbytes.com` (www variant of typo)

**Implementation Benefits**

- **User Experience**: Visitors who mistype the domain still reach the correct site
- **Brand Protection**: Prevents competitors from registering typo domains
- **SEO Consolidation**: All typo traffic redirects to canonical domain
- **Verbal Direction**: When saying "denver-bytes" aloud, listeners might hear "denver-bites"

**Cost Analysis**

- Domain registration: ~$12/year per typo domain
- Infrastructure: Minimal (same CloudFront function handles redirects)
- Maintenance: Zero additional operational overhead

### SEO Impact Measurement

#### Before Canonicalization

```
Site Authority Split:
├── denverbytes.com (50% authority)
└── www.denverbytes.com (50% authority)

Search Results:
├── Both versions may appear in results
├── Inconsistent ranking positions
└── Duplicate content warnings in Search Console
```

#### After Canonicalization

```
Consolidated Authority:
└── denverbytes.com (100% authority)

Search Results:
├── Only canonical version appears
├── Consistent ranking positions
└── Clean Search Console reports
```

### Implementation Verification

#### HTTP Response Testing

```bash
# Canonical domain should return 200 OK
$ curl -I https://denverbytes.com
HTTP/2 200
content-type: text/html
server: CloudFront

# WWW should return 301 redirect
$ curl -I https://www.denverbytes.com
HTTP/2 301
server: CloudFront
location: https://denverbytes.com/

# Typo domain should return 301 redirect
$ curl -I https://denverbites.com
HTTP/2 301
server: CloudFront
location: https://denverbytes.com/

# Typo domain www should return 301 redirect
$ curl -I https://www.denverbites.com
HTTP/2 301
server: CloudFront
location: https://denverbytes.com/
```

#### DNS Resolution Testing

```bash
# Apex domain resolves to CloudFront
$ dig denverbytes.com A +short
13.226.251.129
13.226.251.62
13.226.251.15
13.226.251.19

# WWW resolves via CNAME to apex
$ dig www.denverbytes.com CNAME +short
denverbytes.com.
```

#### Search Engine Testing

```bash
# Google Search Console should show:
# - Primary domain: denverbytes.com
# - No duplicate content warnings
# - Consistent indexing patterns

# Google search should show:
# - Only canonical URLs in results
# - No www.denverbytes.com results
```

### Best Practices Compliance

#### ✅ What This Implementation Does Right

1. **301 Permanent Redirects**: Tells search engines the canonical version is permanent
2. **Edge-Level Processing**: Redirects happen at CloudFront edge, not origin
3. **Preserve URL Paths**: `www.example.com/page` → `example.com/page`
4. **HTTPS Enforcement**: All redirects maintain HTTPS protocol
5. **Global Consistency**: Same behavior across all geographic regions

#### ❌ Common Mistakes This Avoids

1. **302 Temporary Redirects**: Would not transfer SEO authority
2. **JavaScript Redirects**: Search engines might not follow them
3. **Meta Refresh Redirects**: Slower and less reliable
4. **Inconsistent Implementation**: Some pages redirect, others don't
5. **HTTP to HTTPS Issues**: Mixed protocol redirects

### Integration with Content Management

#### Internal Linking Strategy

```html
<!-- Always use canonical URLs in internal links -->
<a href="https://denverbytes.com/about">About</a>

<!-- Never link to www version -->
<a href="https://www.denverbytes.com/about">❌ Wrong</a>
```

#### Sitemap Configuration

```xml
<!-- sitemap.xml should only contain canonical URLs -->
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://denverbytes.com/</loc>
    <lastmod>2026-01-03</lastmod>
  </url>
  <!-- Never include www versions -->
</urlset>
```

#### Canonical Link Tags

```html
<!-- Every page should specify its canonical URL -->
<link rel="canonical" href="https://denverbytes.com/current-page" />
```

### Monitoring and Maintenance

#### Google Search Console Setup

1. Add both `denverbytes.com` and `www.denverbytes.com` as properties
2. Set `denverbytes.com` as the preferred domain
3. Monitor for duplicate content warnings
4. Track canonical URL indexing patterns

#### Analytics Configuration

1. Configure Google Analytics for canonical domain only
2. Set up goal funnels using canonical URLs
3. Monitor traffic patterns for redirect effectiveness

#### Regular Audits

```bash
# Monthly verification script
#!/bin/bash
echo "Testing canonical domain implementation..."

# Test canonical response
CANONICAL=$(curl -s -o /dev/null -w "%{http_code}" https://denverbytes.com)
echo "Canonical domain: $CANONICAL (should be 200)"

# Test www redirect
WWW=$(curl -s -o /dev/null -w "%{http_code}" https://www.denverbytes.com)
echo "WWW redirect: $WWW (should be 301)"

# Test typo domain redirect
TYPO=$(curl -s -o /dev/null -w "%{http_code}" https://denverbites.com)
echo "Typo domain redirect: $TYPO (should be 301)"

# Test typo domain www redirect
TYPO_WWW=$(curl -s -o /dev/null -w "%{http_code}" https://www.denverbites.com)
echo "Typo domain WWW redirect: $TYPO_WWW (should be 301)"

# Test redirect locations
WWW_LOCATION=$(curl -s -I https://www.denverbytes.com | grep -i location | cut -d' ' -f2)
echo "WWW redirect target: $WWW_LOCATION (should be https://denverbytes.com/)"

TYPO_LOCATION=$(curl -s -I https://denverbites.com | grep -i location | cut -d' ' -f2)
echo "Typo redirect target: $TYPO_LOCATION (should be https://denverbytes.com/)"
```

This canonical domain implementation ensures optimal SEO performance while maintaining enterprise-grade reliability and global consistency.
