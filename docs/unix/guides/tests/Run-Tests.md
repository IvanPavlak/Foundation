# Run-Tests

Runs the bats suites of `Unix/tests` in parallel workers, plus the shellcheck and `shfmt` lint,
the way the Unix CI workflow does.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Run-Tests
Run-Tests layout
Run-Tests --quick
Run-Tests --changed
Run-Tests --changed --quick
Run-Tests --changed layout
Run-Tests Open-Project --filter 'opens' --no-lint
Run-Tests --workers 4 --detailed
Run-Tests --path Unix/tests/modules/Git
Run-Tests --update-contract-baseline
Run-Tests --lint-files
```

## Related

- [`Run-Tests` in the Tests module reference](../../modules/Tests.md#run-tests)
- [Tests configuration guides](README.md)
