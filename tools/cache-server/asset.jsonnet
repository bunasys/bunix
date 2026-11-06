// bb_remote_asset: the shared BuildStream cache's index, which maps artifact
// and source names to content in bb_storage (storage.jsonnet).  The block
// counts and attempt limits are BuildStream's own test values.
local dir = '/srv/ci/bst-cache/asset/';

{
  grpcServers: [{
    // only this host, like bb_storage
    listenAddresses: ['127.0.0.1:7981'],
    authenticationPolicy: { allow: {} },
  }],
  maximumMessageSizeBytes: 16 * 1024 * 1024,
  contentAddressableStorage: {
    grpc: { client: { address: '127.0.0.1:7982' } },
  },
  // BuildStream only stores and looks up names; nothing is ever fetched
  // from elsewhere on a miss (code 5: gRPC's NOT_FOUND)
  fetcher: {
    'error': { code: 5, message: 'Asset Not Found' },
  },
  assetCache: {
    blobAccess: {
      'local': {
        keyLocationMap: {
          onBlockDevice: {
            file: { path: dir + 'key_location_map', sizeBytes: 16 * 1024 * 1024 },
          },
          maximumGetAttempts: 8,
          maximumPutAttempts: 32,
        },
        oldBlocks: 8,
        currentBlocks: 24,
        newBlocks: 1,
        blocksOnBlockDevice: {
          source: {
            file: { path: dir + 'blocks', sizeBytes: 1024 * 1024 * 1024 },
          },
          spareBlocks: 3,
        },
        persistent: {
          stateDirectoryPath: dir + 'state',
          minimumEpochInterval: '300s',
        },
      },
    },
  },
  allowUpdatesForInstances: [''],
  fetchAuthorizer: { allow: {} },
  pushAuthorizer: { allow: {} },
}
