// bb_remote_asset: the shared BuildStream cache's index, which maps artifact
// and source names to content in bb_storage (storage.jsonnet).  The block
// counts and attempt limits are BuildStream's own test values.
local dir = '/srv/ci/bst-cache/asset/';
// install.sh reads this line, to see a change
local blocksBytes = 1024 * 1024 * 1024;
// Pushes only through 7981 (README.md, "Who can put artifacts in it")
local access = import 'access.libsonnet';

{
  // only this host, like bb_storage
  grpcServers: [
    access.server('127.0.0.1:7981', 'read-write'),
    access.server('127.0.0.1:7983', 'pull'),
  ],
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
            file: { path: dir + 'blocks', sizeBytes: blocksBytes },
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
  pushAuthorizer: access.readWriteOnly,
}
