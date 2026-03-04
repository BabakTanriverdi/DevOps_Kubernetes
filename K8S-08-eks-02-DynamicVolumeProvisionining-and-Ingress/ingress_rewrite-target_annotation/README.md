# Hands-on Kubernetes : http://nginx.ingress.kubernetes.io/rewrite-target annotaion

Purpose of the this hands-on training is to give students the knowledge of nginx ingress controller.

## Learning Outcomes

At the end of the this hands-on training, students will be able to;

- Learn to nginx ingress controller.

## Outline

- Part 1 - nginx ingress without `http://nginx.ingress.kubernetes.io/rewrite-target annotaion` annotation

- Part 2 - nginx ingress without `http://nginx.ingress.kubernetes.io/rewrite-target annotaion` annotation


## Part 1 - nginx ingress without `http://nginx.ingress.kubernetes.io/rewrite-target annotaion` annotation

- There is a clarusshop app that is composed of two microservice. `storefront` and `account` services.

- The application manifest files are under the `k8s` folder.

- At the first example `storefront pods` publish its content from `/` path and `account pods` publish its content from `/account` path.

- storefront.py

```py
from flask import Flask

app = Flask(__name__)

@app.route('/')
def storefront():
    return '<h1>Welcome to clarusshop!</h1><h2>/account</h2>'

if __name__ == '__main__':
   app.run(host='0.0.0.0', port=80)
```

- account.py.

```py
from flask import Flask

app = Flask(__name__)

@app.route('/account')   # Notice the path
def account():
    return '<h1>This is account service.</h1>'

if __name__ == '__main__':
   app.run(host='0.0.0.0', port=80)
```

- ing.yaml

```bash
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-clarusshop
  # annotations:
  #   nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: storefront-service
                port: 
                  number: 80
          - path: /account
            pathType: Prefix
            backend:
              service:
                name: account-service
                port: 
                  number: 80
```

- We do not need `nginx.ingress.kubernetes.io/rewrite-target: /` anotation. Because the `account service` publish its content from `/account` path.

- Create the objects.

```bash
kubectl apply -f k8s
kubectl apply -f ing.yaml
```

- Get the ingress address.

```bash
$ kubectl get ing
NAME                 CLASS   HOSTS   ADDRESS        PORTS   AGE
ingress-clarusshop   nginx   *       192.168.49.2   80      41m
$ curl 192.168.49.2/account
<h1>This is account service.</h1>
```

## Part 2 - nginx ingress with `http://nginx.ingress.kubernetes.io/rewrite-target annotaion` annotation

- This time we use `clarusway/cs-account-without-path` image. 

- New image code as below.
```py
from flask import Flask

app = Flask(__name__)

@app.route('/')   # Notice that rhe path is /
def account():
    return '<h1>This is account service.</h1>'

if __name__ == '__main__':
   app.run(host='0.0.0.0', port=80)
```

- Change the `k8s/account-deploy.yaml` image as below.

```yaml
image: clarusway/cs-account-without-path
```

- Update the account deploy.

```bash
kubectl apply -f k8s/account-deploy.yaml
kubectl apply -f ing.yaml
```

- Wait for the nw pod and check the ingress again.

```bash
$ kubectl get ing
NAME                 CLASS   HOSTS   ADDRESS        PORTS   AGE
ingress-clarusshop   nginx   *       192.168.49.2   80      51m
$ curl 192.168.49.2/account
<!doctype html>
<html lang=en>
<title>404 Not Found</title>
<h1>Not Found</h1>
<p>The requested URL was not found on the server. If you entered the URL manually please check your spelling and try again.</p>
```

- As we see the request URL was not found. Because, the `account service` publish its content from `/` path now, but nginx search for `/account` path. We will rewrite target `/account` path as `/`. For this, we uncomment annotata in the ing.yaml file.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-clarusshop
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: storefront-service
                port: 
                  number: 80
          - path: /account
            pathType: Prefix
            backend:
              service:
                name: account-service
                port: 
                  number: 80
```

- Update the ingress and check it again.

```bash
$ kubectl apply -f ing.yaml
$ kubectl get ing
NAME                 CLASS   HOSTS   ADDRESS        PORTS   AGE
ingress-clarusshop   nginx   *       192.168.49.2   80      51m
$ curl 192.168.49.2/account
<h1>This is account service.</h1>
```

- This time it works.