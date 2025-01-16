# OpenEmailCore

The core logic should be independent of the client implementation and platfrom agnostic. 

This module handles
- crypto
- networking
- persistence of Mail/HTTPS protocol related data (application data is handled by client implementation)

## Models

In order to hide implementation details, especially regarding persistence, it may be necessary to implement two sets of models: A public model which is used by clients, and an internal model.

For example, message data could be exposed through the public API as a 

```
struct Message {
    let id: String
    ...
}
```

while internally it is implemented as

```
@Model
class PersistedMessage {
    @Attribute(.unique) var id: String
    ...
}
```
