// Read-write and pull-only ports, for storage.jsonnet and asset.jsonnet.
//
// Every request is labelled with the access of the port it came in on, and
// writes are allowed only with the label 'read-write'.  The Fly machine gets
// the pull-only ports, so nothing logged in there can put into the cache
// that releases are made from (README.md).
{
  server(address, access): {
    listenAddresses: [address],
    authenticationPolicy: { allow: { public: { access: access } } },
  },

  readWriteOnly: {
    jmespathExpression: {
      expression: "authenticationMetadata.public.access == 'read-write'",
      // checked when the service starts: it does not start if these fail
      testVectors: [
        {
          input: { authenticationMetadata: { public: { access: 'read-write' } }, instanceName: '' },
          expectedOutput: true,
        },
        {
          input: { authenticationMetadata: { public: { access: 'pull' } }, instanceName: '' },
          expectedOutput: false,
        },
      ],
    },
  },
}
