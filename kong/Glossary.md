### 1. apigroup
- Associated with our own defined upstream services, an apigroup can contain multiple snapshot API.
### 2. SnapshotAPI
- The definition of API routing is actually to match client requests by defining some rules.
### 3. publishapis
- The version and status of API routing are associated with the snapshot API. A snapshot API can correspond to multiple public APIs, meaning that an API routing can have multiple different versions, and only one public API is in a published state in each gateway environment.
### 4. plugin
- Gateway plugins are plugins that perform actions such as authentication, flow limiting, etc. before or after a request is proxied to an API.
### 5. pluginrel
- The plugin binding relationship of the gateway, that is, the plugin and API binding relationship.
### 6. Consumer
- Applications can correspond a Consumer to a user in the actual application.
### 7. Authorize
- Authorization relationship refers to the corresponding relationship between an API authorized to a consumer.
### 8. Secret
- Use secret to save the access credentials of the consumer.