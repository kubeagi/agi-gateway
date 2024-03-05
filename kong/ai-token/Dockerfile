FROM golang:alpine as builder
# 更换alpine下载镜像
RUN sed -i 's!http://dl-cdn.alpinelinux.org/!https://mirrors.ustc.edu.cn/!g' /etc/apk/repositories
RUN apk add --no-cache git gcc libc-dev curl
RUN mkdir /go-plugins
RUN go env -w GOPROXY=https://goproxy.cn,direct
RUN go env -w GOSUMDB=sum.golang.google.cn
RUN go env -w GO111MODULE=on
COPY ./ai-token.go /go-plugins/ai-token.go
RUN cd /go-plugins && go mod init ai-token && go get github.com/Kong/go-pdk && go get github.com/pkoukk/tiktoken-go && go mod tidy && go build ai-token.go
#RUN /go-plugins/ai-token
#####################
## Release image
#####################
FROM kong:2024011515
# Copy Go files
COPY --from=builder  /go-plugins/ai-token /usr/local/bin/
COPY constants.lua /usr/local/share/lua/5.1/kong/constants.lua
ENV KONG_PLUGINS=bundled,ai-token
ENV KONG_PLUGINSERVER_NAMES=ai-token
ENV KONG_PLUGINSERVER_AI_TOKEN_QUERY_CMD="ai-token -dump"

USER kong

