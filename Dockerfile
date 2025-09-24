# dummy change
# First stage:
# Building a frontend.
#
ARG REGISTRY="420361828844.dkr.ecr.ap-southeast-1.amazonaws.com"
FROM ${REGISTRY}/xendit/golang-1.21:1.4.0 AS frontend
ARG TARGETARCH

# Move to a working directory (/static).
WORKDIR /static

# Install npm (with latest nodejs) and yarn (globally, in silent mode).
RUN apk add --no-cache npm && \
    npm i -g -s --unsafe-perm yarn

# Copy only ./ui folder to the working directory.
COPY ui .

# Run yarn scripts (install & build).
RUN yarn install && yarn build

#
# Second stage:
# Building a backend.
#

ARG REGISTRY="420361828844.dkr.ecr.ap-southeast-1.amazonaws.com"
FROM ${REGISTRY}/xendit/golang-1.21:1.4.0 AS backend
ARG TARGETARCH

# Move to a working directory (/build).
WORKDIR /build

# Copy and download dependencies.
COPY go.mod go.sum ./
RUN go mod download

# Copy a source code to the container.
COPY . .

# Copy frontend static files from /static to the root folder of the backend container.
COPY --from=frontend ["/static/build", "ui/build"]

# Set necessary environmet variables needed for the image and build the server.
ENV CGO_ENABLED=0 GOOS=linux GOARCH=${TARGET_ARCH}

# Run go build (with ldflags to reduce binary size).
RUN go build -ldflags="-s -w" -o asynqmon .

#
# Third stage:
# Creating and running a new scratch container with the backend binary.
#

ARG REGISTRY="420361828844.dkr.ecr.ap-southeast-1.amazonaws.com"
FROM ${REGISTRY}/xendit/alpine-3.18:1.1.0 as base

# Copy binary from /build to the root folder of the scratch container.
COPY --from=backend ["/build/asynqmon", "/"]

EXPOSE 8080

# Command to run when starting the container.
ENTRYPOINT ["/asynqmon"]
