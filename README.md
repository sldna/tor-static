# tor-static
Static linked Tor proxy Container.

## How to use?

```
docker pull ghcr.io/sldna/tor-static:latest
```
After pull the image run it
```
docker run -d --name tor --restart unless-stopped -p 9050:9050 -p 9051:9051 sldna/tor-static:latest
```