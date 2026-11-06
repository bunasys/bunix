// bb_storage: the shared BuildStream cache's content-addressed store (CAS).
// BuildStream stores every artifact's files here; bb_remote_asset
// (asset.jsonnet) maps artifact names to them.  README.md says how it is
// installed and reached.
//
// The store is a fixed-size ring of blocks in one file on the USB disk: when
// it is full, the oldest blocks are reused (least recently used content goes
// first).  `persistent` keeps its index across restarts.  The block counts
// and attempt limits are Buildbarn's example values (bb-deployments).
local dir = '/srv/ci/bst-cache/cas/';

{
  grpcServers: [{
    // only this host; other machines come in through SSH tunnels (README.md)
    listenAddresses: ['127.0.0.1:7982'],
    authenticationPolicy: { allow: {} },
  }],
  maximumMessageSizeBytes: 16 * 1024 * 1024,
  contentAddressableStorage: {
    backend: {
      'local': {
        keyLocationMap: {
          onBlockDevice: {
            file: { path: dir + 'key_location_map', sizeBytes: 1024 * 1024 * 1024 },
          },
          maximumGetAttempts: 16,
          maximumPutAttempts: 64,
        },
        oldBlocks: 8,
        currentBlocks: 24,
        newBlocks: 3,
        blocksOnBlockDevice: {
          // the size install.sh allocates up front (README.md, "Disk space")
          source: {
            file: { path: dir + 'blocks', sizeBytes: 140 * 1024 * 1024 * 1024 },
          },
          spareBlocks: 3,
        },
        persistent: {
          stateDirectoryPath: dir + 'state',
          minimumEpochInterval: '300s',
        },
      },
    },
    getAuthorizer: { allow: {} },
    putAuthorizer: { allow: {} },
    findMissingAuthorizer: { allow: {} },
  },
}
