# Build stage with Spack pre-installed and ready to be used
FROM spack/ubuntu-bionic:latest as builder


# What we want to install and how we want to install it
# is specified in a manifest file (spack.yaml)
RUN mkdir /opt/spack-environment \
&&  (echo "spack:" \
&&   echo "  specs:" \
&&   echo "  - hiop@0.4.6+mpi+raja^openmpi" \
&&   echo "  config:" \
&&   echo "    clingo: true" \
&&   echo "    install_tree: /opt/software" \
&&   echo "  view: /opt/view" \
&&   echo "  packages:" \
&&   echo "    all:" \
&&   echo "      target:" \
&&   echo "      - x86_64" \
&&   echo "    openssl:" \
&&   echo "      version:" \
&&   echo "      - 1.1.1g" \
&&   echo "    openblas:" \
&&   echo "      version:" \
&&   echo "      - 0.3.10" \
&&   echo "    openmpi:" \
&&   echo "      version:" \
&&   echo "      - 3.1.6" \
&&   echo "    perl:" \
&&   echo "      version:" \
&&   echo "      - 5.30.3" \
&&   echo "  concretization: together") > /opt/spack-environment/spack.yaml

# Install the software, remove unnecessary deps
RUN cd /opt/spack-environment && \
    spack mirror add e4s https://cache.e4s.io && \
    spack buildcache keys -it && \
    spack buildcache list && \
    spack env activate . && \
    spack install --fail-fast && \
    spack gc -y

# Strip all the binaries
RUN find -L /opt/view/* -type f -exec readlink -f '{}' \; | \
    xargs file -i | \
    grep 'charset=binary' | \
    grep 'x-executable\|x-archive\|x-sharedlib' | \
    awk -F: '{print $1}' | xargs strip -s

# Modifications to the environment that are necessary to run
RUN cd /opt/spack-environment && \
    spack env activate --sh -d . >> /etc/profile.d/z10_spack_environment.sh


# Bare OS image to run the installed executables
FROM ubuntu:18.04

COPY --from=builder /opt/spack-environment /opt/spack-environment
COPY --from=builder /opt/software /opt/software
COPY --from=builder /opt/view /opt/view
COPY --from=builder /etc/profile.d/z10_spack_environment.sh /etc/profile.d/z10_spack_environment.sh



ENTRYPOINT ["/bin/bash", "--rcfile", "/etc/profile", "-l"]
