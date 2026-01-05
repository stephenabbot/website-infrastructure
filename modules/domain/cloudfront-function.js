function handler(event) {
    var request = event.request;
    var headers = request.headers;
    var host = headers.host.value;
    var uri = request.uri;
    
    // Redirect denverbites.com (typo domain) to denverbytes.com
    if (host.includes('denverbites.com')) {
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                'location': { value: 'https://denverbytes.com' + uri }
            }
        };
    }
    
    // Redirect www subdomain to apex domain (canonical URL)
    if (host.startsWith('www.')) {
        var canonicalHost = host.replace('www.', '');
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                'location': { value: 'https://' + canonicalHost + uri }
            }
        };
    }
    
    // Directory index handling for non-www requests
    // If URI ends with '/', append 'index.html'
    if (uri.endsWith('/')) {
        request.uri += 'index.html';
    }
    // If URI has no file extension and doesn't end with '/', append '/index.html'
    else if (!uri.includes('.') && !uri.endsWith('/')) {
        request.uri += '/index.html';
    }
    
    return request;
}
