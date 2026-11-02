# A placement checkpoint derived from a previous GRT database still contains
# dbGuide objects.  A fresh global-route run must not append its guides to
# that old layer policy.  Delete only cached guides and fully orphaned nets;
# actual cells, connections, PDN wires and clock routing constraints remain.
source /home/joelphilip/Documents/ethernet_formal/physical/decoupled_pre_grt.tcl
set block [ord::get_db_block]
set guide_count 0
set orphan_count 0
foreach net [$block getNets] {
  if {![$net isSpecial] && ![llength [$net getITerms]] && ![llength [$net getBTerms]]} {
    incr guide_count [llength [$net getGuides]]
    odb::dbNet_destroy $net
    incr orphan_count
    continue
  }
  foreach guide [$net getGuides] {
    odb::dbGuide_destroy $guide
    incr guide_count
  }
}
puts "ECO_GRT_CACHE_RESET guides_removed=$guide_count orphan_nets_removed=$orphan_count"
