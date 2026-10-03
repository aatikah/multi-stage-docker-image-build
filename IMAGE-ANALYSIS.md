# Image Analysis

## A. Executive Summary

The original image was described as approximately 1.2 GB, running as root, with 47 known CVEs, and using a poorly optimized Docker build process. In production, that combination creates an unnecessarily large attack surface: the base image likely includes tooling, package managers, development libraries, and root-level write access that can be exploited if the application is compromised.

The optimized image uses a small, pinned Node.js base image, separates build tooling from the runtime image, and creates a dedicated non-root user with UID 1001. In this case, the runtime uses Alpine-based Node to keep the final filesystem compact. Alpine is a common production choice because it reduces image size and package count, but it uses musl rather than glibc and may need testing if the application relies on glibc-specific behavior. The result is a smaller final image, fewer unnecessary packages, a minimized filesystem, and a more conventional production runtime model. The expected operational benefit is easier maintenance, smaller attack surface, cheaper storage and transfer costs, and better alignment with container security best practices.

## B. Image Size Reduction

A naive Dockerfile such as:

```dockerfile
FROM node:latest
WORKDIR /app
COPY . .
RUN npm install
CMD ["node", "server.js"]
```

is inappropriate for production because `node:latest` is a floating tag. It can change over time, making builds non-reproducible and potentially introducing unexpected vulnerabilities or behavior changes. It also tends to include more packages and tooling than a minimal production image needs.

The optimized image is expected to be substantially smaller because it uses a multi-stage approach and copies only necessary files. A minimal Node.js Alpine-based runtime image is often in the low hundreds of MB range, depending on the application and dependency tree, while a naive `node:latest` image can easily be hundreds of MB to over 1 GB when paired with a common application install flow, dev dependencies, and a large build context.

Exact final size depends on the actual application stack, static assets, package manager behavior, and whether the build stage installs dev dependencies or includes native modules. A small application with a minimal dependency graph may finish near a few hundred MB, while a larger application with native libraries or heavy build tooling can be substantially larger. The key point is that a multi-stage build keeps the runtime image free of build tools and package caches, which is the primary reason a production image is smaller.

Estimated size examples:

- Estimated optimized runtime image: roughly 150 MB to 400 MB depending on base image and dependencies.
- Estimated naive image: roughly 700 MB to 1.2 GB or more depending on the app and installation strategy.

These are estimates rather than measured values. No exact image size is claimed here because the image was not actually built and measured in this execution environment.

## C. Multi-stage Build and Attack Surface

The build stage exists to install dependencies and compile or prepare the application when needed. It may contain tools such as a package manager, compiler toolchains, build libraries, or native build dependencies. The runtime stage should contain only the files required to run the application.

The runtime stage should not include build tools, package manager caches, docs, tests, or source files that are not required at runtime. That matters because every additional binary or library increases the size of the filesystem and expands the available attack surface. A smaller image with fewer packages means fewer executables to exploit and fewer vulnerable components to patch.

Removing unnecessary packages reduces attack surface by shrinking the number of binaries and libraries installed at runtime. Fewer installed pieces also means lower operational complexity during patching and fewer opportunities for accidental dependency drift. This is especially important because even if a binary is not directly used, it may still be reachable if an attacker gains code execution or container break-out conditions.

## D. Non-root Security

Running containers as root is dangerous because a compromised process inside the container inherits the root user and its permissions. That can allow file tampering, reading of sensitive files, and greater ability to modify the filesystem or install tooling inside the container. It also increases the impact of a compromise because the process can act more like a privileged host process than a restricted application user.

UID 1001 is a conventional non-privileged user ID. It is assigned to the application user so the container does not need root-level execution. In the Dockerfile, the image creates an operating-system user named `appuser` and sets that user to UID 1001. The final stage executes with:

```dockerfile
USER appuser
```

This matters because it limits the damage caused by a compromised application process. If an attacker gains code execution in the app, they do not immediately have root privileges inside the container. That reduces the blast radius of a single application compromise and enforces a least-privilege model for the runtime container.

However, non-root execution does not provide complete isolation. A container is still running with kernel-level access and shares the host kernel, and a vulnerability in the container runtime or application can still be dangerous. Non-root is a valuable hardening step, but it is not a full security boundary by itself.

## E. CI Image Scanning

A practical image-scanning tool is Trivy. It can scan container images for known vulnerabilities, including OS packages and application dependencies. A CI-friendly command is:

```bash
trivy image --severity HIGH,CRITICAL --exit-code 1 your-image:tag
```

The scanner checks the image filesystem for vulnerable packages and compares them to vulnerability databases. Using HIGH and CRITICAL severity as a release gate is common because those findings are usually more urgent to remediate than low-severity issues. However, the exact threshold should be adjusted to the organization’s risk tolerance, supported runtimes, and regulatory requirements. The policy should reflect which assets are production-critical and whether compensating controls exist.

Scanning should occur before pushing the production image to a registry so vulnerable images are caught before they reach deployment. This stops obvious defects from entering the runtime environment and allows the team to remediate before release.

## F. Handling a CVE With No Available Fix

When a CVE exists in the base image but no upstream fix is available, the correct process is not to ignore it blindly. Instead, the team should:

1. Verify whether the CVE is actually exploitable in the application and container runtime.
2. Identify the vulnerable package and the dependency path that introduces it.
3. Check whether an alternative base image or version removes the issue.
4. Confirm whether the vulnerable component is actually used at runtime.
5. Reduce exposure through configuration, file permissions, and runtime hardening.
6. Apply compensating controls such as restricted capabilities, readonly filesystems, or network segmentation.
7. Document the risk and record a temporary exception if mitigation is incomplete.
8. Monitor vendor and upstream advisories until a fixed version is available.
9. Upgrade as soon as a patch or replacement image is available.

This is a realistic and responsible remediation workflow. It acknowledges that a CVE may be present without a practical fix in the current release window, but it still requires deliberate risk handling and remediation planning.

## G. Docker Security Decisions

| Decision | Implementation | Security/Operational Benefit |
| --- | --- | --- |
| Minimal base image | `node:20.11.1-alpine3.20` | Reduces package count and filesystem size |
| Pinned version | Explicit version string, not `latest` | Stable, reproducible builds and more predictable patching |
| Multi-stage build | Separate build and runtime stages | Keeps build tools and caches out of the final image |
| Non-root user | `appuser` with UID 1001 | Reduces impact of container compromise |
| `.dockerignore` | Excludes `.git`, `node_modules`, tests, logs, and env files | Keeps build context smaller and avoids leaking secrets |
| Production dependencies only | `npm ci --omit=dev` | Removes unnecessary libraries from the runtime image |
| HEALTHCHECK | HTTP check against `/health` | Detects unhealthy app process before traffic is routed |
| Exec-form CMD | `CMD ["node", "server.js"]` | Avoids shell interpretation and is safer/cleaner |

## Validation

The assignment requires validation when Docker and Trivy are available. In this execution environment, Docker and Trivy were not verified to be available, so validation was not executed.

```text
Validation not executed because Docker/Trivy was unavailable in the execution environment.
```

This is consistent with the requirement to avoid fabricating results or claiming unverified behavior.
