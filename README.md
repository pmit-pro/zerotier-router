# ZeroTier-Router
A ZeroTier router container for docker and kubernetes

## Summary
[ZeroTier](https://zerotier.com) is a quick and easy way to create secure networks over the internet.

This linux/amd64 and linux/arm64 alpine linux based container implements a simple router that is capable of routing traffic from your ZeroTier nodes to the
container / host network.

It can be used to securely access your private network / docker host or kubernetes cluster from anywhere around the globe by forwarding and masquerading
packets from the ZeroTier interface to the container interface.

### Docker usage
```sh
docker run -d --cap-add=NET_ADMIN --name zt --env ZT_NETWORKS="<NetworkID>" \
    -v ztvol:/var/lib/zerotier-one \
    -v /dev/net/tun:/dev/net/tun \
    ghcr.io/pmit-pro/zerotier-router
```
The volume is needed to save the identity information of the ZeroTier instance - otherwise a new identity would be created on every container start.
Another way of providing identity information is to set the ZT_ID_PUBLIC and ZT_ID_SECRET environment variables (These have precedence and, if present, OVERWRITE the identity information already stored on a volume).

### Kubernetes usage
```sh
helm repo add zerotier-router https://pmit-pro.github.io/zerotier-router
helm repo update
helm install zerotier-router zerotier-router/zerotier-router
```
```sh
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/pvc.yaml
kubectl apply -f k8s/deployment.yaml
```
Per default kubernetes does not allow the usage of the **net.ipv4.ip_forward** kernel parameter for pods. There are two solutions for this problem:
1. Uncomment the *privileged: true* line in deployment.yaml to run the pod in privileged mode (not recommended)
2. Allow the **net.ipv4.ip_forward** kernel parameter in your kubelet configuration by adding the following argument to your kubelet service and then
   restart your kubelet service
```sh
--allow-unsafe-sysctls="net.ipv4.ip_forward"
```
