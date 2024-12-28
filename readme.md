# swift-getitem

This is part of the getitem kata: [python-getitem](https://github.com/algal/python-getitem),  [rust-getitem](<https://github.com/algal/rust-getitem>), [swift-getitem](<https://github.com/algal/swift-getitem>). `getitem` is a command-line utility which lets you use Python splice syntax to filter rows and columns. This is to present a handier interface than cat, head, tail, cut, awk, etc.. It buffers only as much as necessary, and can be used with streams or files.

## To run and get help

```sh
./getitem -h
```

# To build

Builds into .build/release/getitem:

```
swift build --configuration=release
```

# To run tests

```
swift test
```


