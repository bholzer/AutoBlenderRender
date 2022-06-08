# API

The Lambda-based API is separated into resource directories, with each file being the source of a Lambda function. These Lambda functions serve as the endpoints of an API Gateway.

## Deploying

There is a deploy script that can deploy one or more functions to an environment selected by the `--environment` option. The default environment name is `auto-blender-render`.

The directory structure determines which Lambda function a given source file belongs to. For example, consider deploying the blend/create function to an environment called `my-farm`:

```
./deploy --environment my-farm --function ./blends/create.rb
```

The `./blends/create.rb` would be uploaded to a Lambda named `my-farm-blends-create`.

## Authentication

The API is protected using a JWT authenticator. A Cognito user pool and client is responsible for identities. To access the API, you must create and confirm a Cognito user.

An authentication token must be provided in the `Authorization` header. To get a token from the CLI you need the `client_id` of the app client that exists in the user pool.

```
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $CLIENT_ID \
  --auth-parameters '{"USERNAME":"YOUR_USERNAME","PASSWORD":"YOUR_PASSWORD"}'
```

This will return an `IdToken` for use in the authorization header.

