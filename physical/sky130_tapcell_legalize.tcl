# Tapcells fragment rows after the first legalization pass.  Re-legalize the
# standard cells around those fixed physical-only cells before PDN validation.
set_placement_padding -global -left 0 -right 0
detailed_placement
check_placement -verbose
