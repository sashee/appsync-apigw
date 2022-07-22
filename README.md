# Example code to show how AppSync can call a private API Gateway API

## Deploy

* ```terraform init```
* ```terraform apply```

## Usage

Send requests to the AppSync API and see what the backend Lambda function got.

```graphql
query MyQuery {
  call(path: "/abc")
}

mutation MyMutation {
  callPost(body: "abc", path: "/post")
}
```

## Cleanup

* ```terraform destroy```
