---
layout: post
comments: true
title: Kibana startup fails with re2.node not valid for use in process library load disallowed by system policy
excerpt: How to fix Kibana startup issue caused by re2.node not valid for use in process library load disallowed by system policy
tags: [kibana,macos]
toc: true
img_excerpt:
---

<img align="center" src="/assets/logos/kibana.svg" width="100" />
<br/>


I was trying to setup Kibana locally on macOS Monterey version 12.5.1 (21G83), so I downloaded [Kibana](https://www.elastic.co/downloads/kibana) and installed it like this:

```shell
$ tar xzf kibana-8.5.3-darwin-aarch64.tar.gz
$ cd cd kibana-8.5.3
```

But when I tried to start Kibana, I encountered the following error:

```shell
$ bin/kibana
[2022-12-21T11:54:31.067+01:00][INFO ][node] Kibana process configured with roles: [background_tasks, ui]
[2022-12-21T11:54:35.134+01:00][FATAL][root] Error: dlopen(/Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node, 0x0001): tried: '/Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node' (code signature in <1683A937-8902-34BD-9886-2F1CC674A96E> '/Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node' not valid for use in process: library load disallowed by system policy)
    at Object.Module._extensions..node (node:internal/modules/cjs/loader:1239:18)
    at Module.load (node:internal/modules/cjs/loader:1033:32)
    at Function.Module._load (node:internal/modules/cjs/loader:868:12)
    at Module.require (node:internal/modules/cjs/loader:1057:19)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at require (node:internal/modules/cjs/helpers:103:18)
    at Object.<anonymous> (/Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/re2.js:3:13)
    at Module._compile (node:internal/modules/cjs/loader:1155:14)
    at Object.Module._extensions..js (node:internal/modules/cjs/loader:1209:10)
    at Module.load (node:internal/modules/cjs/loader:1033:32)
    at Function.Module._load (node:internal/modules/cjs/loader:868:12)
    at Module.require (node:internal/modules/cjs/loader:1057:19)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at require (node:internal/modules/cjs/helpers:103:18)
    at Object.<anonymous> (/Users/dzlab/Tools/kibana-8.5.3/x-pack/plugins/ml/server/saved_objects/service.js:12:34)
    at Module._compile (node:internal/modules/cjs/loader:1155:14)
    at Object.Module._extensions..js (node:internal/modules/cjs/loader:1209:10)
    at Module.load (node:internal/modules/cjs/loader:1033:32)
    at Function.Module._load (node:internal/modules/cjs/loader:868:12)
    at Module.require (node:internal/modules/cjs/loader:1057:19)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at require (node:internal/modules/cjs/helpers:103:18)
    at Object.<anonymous> (/Users/dzlab/Tools/kibana-8.5.3/x-pack/plugins/ml/server/saved_objects/index.js:45:16)
    at Module._compile (node:internal/modules/cjs/loader:1155:14)
    at Object.Module._extensions..js (node:internal/modules/cjs/loader:1209:10)
    at Module.load (node:internal/modules/cjs/loader:1033:32)
    at Function.Module._load (node:internal/modules/cjs/loader:868:12)
    at Module.require (node:internal/modules/cjs/loader:1057:19)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at Module.Hook._require.Module.require (/Users/dzlab/Tools/kibana-8.5.3/node_modules/require-in-the-middle/index.js:101:39)
    at require (node:internal/modules/cjs/helpers:103:18)

 FATAL  Error: dlopen(/Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node, 0x0001): tried: '/Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node' (code signature in <1683A937-8902-34BD-9886-2F1CC674A96E> '/Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node' not valid for use in process: library load disallowed by system policy)
```

I tried to look up for resolutions and the only thing I could found was this [Kibana issue](https://github.com/elastic/kibana/issues/121864) which is closed with a suggestioon to instead install kibana version `7.16.2`. OK so I just need to download that version or try to understand the issue.

In fact, this issue is cause by macOS having stricter signature checks for binaries, causing install issues for a lot of applications (for instance see [link](https://support.blackfire.io/en/articles/3669492-issues-with-macos-catalina)).

In this case, the error basically means osx had put `node.re` in quarantine, we can confirm this using `codesign` and `xattr` as follows: 

```shell
$ codesign -vvvv /Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node
/Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node: valid on disk
/Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node: satisfies its Designated Requirement
$ xattr /Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node
com.apple.quarantine
```

Notice the attribute `com.apple.quarantine` which is added by macOS to any binary file that is considered suspicious. By default all software is suspicious according to macOS, especially if it is downlaoded form the internet and as a result it is put in quarantine by setting the `com.apple.quarantine` extended attribute. So one way to fix this is to remove this attribute with `xattr -d`:

```shell
$ xattr -d com.apple.quarantine /Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node
$ xattr /Users/dzlab/Tools/kibana-8.5.3/node_modules/re2/build/Release/re2.node
```

Notice how after removing the `com.apple.quarantine` attribute we don't see it anymore in the output of `xattr`.

Now we can start Kibana which will be available at http://localhost:5601

```shell
$ bin/kibana
[2022-12-21T12:58:37.552+01:00][INFO ][node] Kibana process configured with roles: [background_tasks, ui]
[2022-12-21T12:58:43.152+01:00][INFO ][plugins-service] Plugin "cloudExperiments" is disabled.

Go to http://localhost:5601/?code=242129 to get started.
```

## That's all folks

I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
