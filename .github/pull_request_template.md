## Summary

Describe the change and the user-visible or technical outcome.

## Validation

- [ ] `swift format lint --recursive --parallel --strict Sources Tests Package.swift scripts/make_icon.swift`
- [ ] `swift test --disable-sandbox`
- [ ] Packaging checks completed when release or bundle behavior changed
- [ ] No credentials, build output, local databases, or private device data added
- [ ] Storage-safety invariants remain intact

## Compatibility

- [ ] Persisted data remains backward compatible, or the migration is documented
- [ ] Measurement protocol version updated if benchmark semantics changed
- [ ] English repository documentation updated
- [ ] Italian user-facing strings updated when applicable
