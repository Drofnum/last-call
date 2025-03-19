// Basic HTTP Authentication for CloudFront with Lambda@Edge
// Adapted from common Lambda@Edge basic auth patterns

'use strict';

// Configure authentication
const authUser = 'lcm-user';
const authPass = 'changeme';

// Set up the auth string
const authString = `Basic ${Buffer.from(`${authUser}:${authPass}`).toString('base64')}`;

exports.handler = (event, context, callback) => {
  // Get the request from the event
  const request = event.Records[0].cf.request;
  const headers = request.headers;

  // Check if the Authorization header exists
  if (headers.authorization) {
    // Get the supplied credentials from the header
    const authValue = headers.authorization[0].value;
    
    // Verify the credentials against our expected values
    if (authValue === authString) {
      // Authentication successful - return the request unchanged
      callback(null, request);
      return;
    }
  }

  // Authentication failed or not provided, return a 401 response
  const response = {
    status: '401',
    statusDescription: 'Unauthorized',
    headers: {
      'www-authenticate': [
        {
          key: 'WWW-Authenticate',
          value: 'Basic realm="Restricted"'
        }
      ],
      'content-type': [
        {
          key: 'Content-Type',
          value: 'text/html'
        }
      ]
    },
    body: 'Unauthorized - Authentication Required'
  };

  callback(null, response);
}; 