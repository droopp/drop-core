## Run tests

    make tests
    make check

## Disable tests

    sed -i 's/test_(/test_i(/g' *.erl

## Enable tests

    sed -i 's/test_i(/test_(/g' *.erl
