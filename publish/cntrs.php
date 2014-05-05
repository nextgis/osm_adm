<?php

if (isset ($_GET['c'])) {
  list($proj, $v, $layer) = explode('/' , $_GET['c'] );
  echo "<a href=\"/data/yav/$proj/.stats/$layer.png\">";
  echo file_get_contents("/home/osm_adm/publish/$proj/$v/.meta/$layer");
  echo "</a>";
};


?> 