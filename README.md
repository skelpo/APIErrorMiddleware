# APIErrorMiddleware

A middleware to catch errors from route handlers and other middleware, and convert them to a JSON response.

## Instillation

Add the package declaration to your project's manifest `dependencies` array:

```swift
.package(url: "https://github.com/skelpo/APIErrorMiddleware.git", from: "0.1.0")
```

Then add the `APIErrorMiddleware` library to the `dependencies` array of any target you want to access the module in.

## Usage

If you only want `APIErrorMiddleware` on some of your routes, you can create a new route group and register your routes with it:

```swift
let api = router.group(APIErrorMiddleware())
api.get(...)
```

However, if you are creating an API service and want all errors to be caught by the middleware, you probably want to add it to the your `MiddlewareConfig`. In `configure.swift`, import the APIErrorMiddleware module. The body of the `configure(_:_:_:)` function probably has a `MiddlewareConfig` instance in it. If not, create one and register it with the services.

You can register the middleware to the `MiddlewareConfig` using:

```swift
middlewares.add(APIErrorMiddleware())
```

Most likely, you will want to register this middleware first. This ensures that all the errors are caught and we don't have any thrown after its responder is run. There are some that you might want to run afterwards though, such as Vapor's built in `DateMiddleware`.