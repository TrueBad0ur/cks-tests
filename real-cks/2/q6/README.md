# Q6 — Verify Platform Binaries

Verify sha512 hashes of Kubernetes binaries and delete those that don't match.

## Expected Hashes

```
kube-apiserver:
  f417c0555bc0167355589dd1afe23be9bf909bf98312b1025f12015d1b58a1c62c9908c0067a7764fa35efdac7016a9efa8711a44425dd6692906a7c283f032c

kube-controller-manager:
  60100cc725e91fe1a949e1b2d0474237844b5862556e25c2c655a33boa8225855ec5ee22fa4927e6c46a60d43a7c4403a27268f96fbb726307d1608b44f38a60

kube-proxy:
  52f9d8ad045f8eee1d689619ef8ceef2d86d50c75a6a332653240d7ba5b2a114aca056d9e513984ade24358c9662714973c1960c62a5cb37dd375631c8a614c6

kubelet:
  4be40f2440619e990897cf956c32800dc96c2c983bf64519854a3309fa5aa21827991559f9c44595098e27e6f2ee4d64a3fdec6baba8a177881f20e3ec61e26c
```

## Steps

```bash
cd /opt/course/6/binaries

# Compute actual hashes
sha512sum kube-apiserver kube-controller-manager kube-proxy kubelet
```

Compare each computed hash against the expected values above. Delete any binary whose hash doesn't match:

```bash
rm <binary-with-wrong-hash>
```

## Script to automate comparison

```bash
cd /opt/course/6/binaries

declare -A expected=(
  [kube-apiserver]="f417c0555bc0167355589dd1afe23be9bf909bf98312b1025f12015d1b58a1c62c9908c0067a7764fa35efdac7016a9efa8711a44425dd6692906a7c283f032c"
  [kube-controller-manager]="60100cc725e91fe1a949e1b2d0474237844b5862556e25c2c655a33boa8225855ec5ee22fa4927e6c46a60d43a7c4403a27268f96fbb726307d1608b44f38a60"
  [kube-proxy]="52f9d8ad045f8eee1d689619ef8ceef2d86d50c75a6a332653240d7ba5b2a114aca056d9e513984ade24358c9662714973c1960c62a5cb37dd375631c8a614c6"
  [kubelet]="4be40f2440619e990897cf956c32800dc96c2c983bf64519854a3309fa5aa21827991559f9c44595098e27e6f2ee4d64a3fdec6baba8a177881f20e3ec61e26c"
)

for binary in "${!expected[@]}"; do
  actual=$(sha512sum "$binary" | awk '{print $1}')
  if [ "$actual" != "${expected[$binary]}" ]; then
    echo "MISMATCH: $binary — deleting"
    rm "$binary"
  else
    echo "OK: $binary"
  fi
done
```

## Notes

- Read hashes carefully — some characters look similar (0/o, 1/l)
- sha512sum output format: `<hash>  <filename>`
- Only delete binaries that actually mismatch — don't delete all of them
