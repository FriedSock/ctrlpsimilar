require 'byebug'
require File.join(File.dirname(__FILE__), 'predictor.rb')
require File.join(File.dirname(__FILE__), 'init.rb')


TEMP_FILENAME = '/tmp/commit_files.txt'

def html_file filehash, linkarray, weights, ob_keys
  nodeDefs = ""
  (0..filehash.length-1).each do |i|
  filename = filehash.select{|key, value| value == i }.first.first
    nodeDefs += <<-NODEDEF
var node = {
  label : "#{filename}"
};
nodes.push(node);
labelAnchors.push({
  node : node
});
labelAnchors.push({
  node : node
});
    NODEDEF
  end

  links = ""
  linkarray.each_with_index do |nodes, i|
    links += <<-LINKDEF
links.push({
  source : #{nodes[0]},
  target : #{nodes[1]},
  weight : #{weights[i]}
});
    LINKDEF
  end

  obdefs = "var obs = [];\n"
  ob_keys.each do |ok|
    obdefs += <<-OBDEF
      obs.push("#{ok}");
    OBDEF
  end

  return <<-FILE
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN">
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Force based label placement</title>
    <script type="text/javascript" src="http://mbostock.github.com/d3/d3.js?2.6.0"></script>
    <script type="text/javascript" src="http://mbostock.github.com/d3/d3.layout.js?2.6.0"></script>
    <script type="text/javascript" src="http://mbostock.github.com/d3/d3.geom.js?2.6.0"></script>
  </head>
  <body>
<script type="text/javascript" charset="utf-8">
      var w = 960, h = 500;

      var labelDistance = 0;

      var vis = d3.select("body").append("svg:svg").attr("width", w).attr("height", h);

      vis.append("rect")
        .attr("width", "100%")
        .attr("height", "100%")
        .attr("fill", "#F0F0F0")
        .attr("cursor","move")
        .call(d3.behavior.zoom()
          .on("zoom", function() {

            translatePos=d3.event.translate;
            var value = zoomWidgetObj.value.target[1]*2;

            //detect the mousewheel event, then subtract/add a constant to the zoom level and transform it
            if (d3.event.sourceEvent.type=='mousewheel' || d3.event.sourceEvent.type=='DOMMouseScroll'){
              if (d3.event.sourceEvent.wheelDelta){
                if (d3.event.sourceEvent.wheelDelta > 0){
                  value = value + 0.1;
                }else{
                  value = value - 0.1;
                }
              }else{
                if (d3.event.sourceEvent.detail > 0){
                  value = value + 0.1;
                }else{
                  value = value - 0.1;
                }
              }
            }
          transformVis(d3.event.translate,value);
          }));

      vis = vis.append('svg:g')
               .call(d3.behavior.zoom().on("zoom", rescale))
               .on("dblclick.zoom", null);

      var nodes = [];
      var labelAnchors = [];
      var labelAnchorLinks = [];
      var links = [];

      #{nodeDefs}

      for(var i = 0; i < nodes.length; i++) {
        labelAnchorLinks.push({
          source : i * 2,
          target : i * 2 + 1,
          weight : 1
        });
      };

      #{links}

      #{obdefs}

      var force = d3.layout.force().size([w, h]).nodes(nodes).links(links).gravity(1).linkDistance(50).charge(-3000).linkStrength(function(x) {
        return x.weight * 10
      });


      force.start();

      var force2 = d3.layout.force().nodes(labelAnchors).links(labelAnchorLinks).gravity(0).linkDistance(0).linkStrength(8).charge(-100).size([w, h]);
      force2.start();

      var link = vis.selectAll("line.link").data(links).enter().append("svg:line").attr("class", "link").style("stroke", "#CCC");

      var node = vis.selectAll("g.node").data(force.nodes()).enter().append("svg:g").attr("class", "node");
      node.append("svg:circle").attr("r", 5).style("fill", function(d,i) {
            return obs.indexOf(d.label) > -1 ? '#0033CC' : '#ffffff';
            }).style("stroke", "#FFF").style("stroke-width", 3);
      node.call(force.drag);


      var anchorLink = vis.selectAll("line.anchorLink").data(labelAnchorLinks)//.enter().append("svg:line").attr("class", "anchorLink").style("stroke", "#999");

      var anchorNode = vis.selectAll("g.anchorNode").data(force2.nodes()).enter().append("svg:g").attr("class", "anchorNode");
      anchorNode.append("svg:circle").attr("r", 0).style("fill", function(d, i) {
         return  '#333333'
        });
        anchorNode.append("svg:text").text(function(d, i) {
        return i % 2 == 0 ? "" : d.node.label
      }).style("fill", "#555").style("font-family", "Arial").style("font-size", 12);

      var updateLink = function() {
        this.attr("x1", function(d) {
          return d.source.x;
        }).attr("y1", function(d) {
          return d.source.y;
        }).attr("x2", function(d) {
          return d.target.x;
        }).attr("y2", function(d) {
          return d.target.y;
        });

      }

      var updateNode = function() {
        this.attr("transform", function(d) {
          return "translate(" + d.x + "," + d.y + ")";
        });

      }


      force.on("tick", function() {

        force2.start();

        node.call(updateNode);

        anchorNode.each(function(d, i) {
          if(i % 2 == 0) {
            d.x = d.node.x;
            d.y = d.node.y;
          } else {
            var b = this.childNodes[1].getBBox();

            var diffX = d.x - d.node.x;
            var diffY = d.y - d.node.y;

            var dist = Math.sqrt(diffX * diffX + diffY * diffY);

            var shiftX = b.width * (diffX - dist) / (dist * 2);
            shiftX = Math.max(-b.width, Math.min(0, shiftX));
            var shiftY = 5;
            this.childNodes[1].setAttribute("transform", "translate(" + shiftX + "," + shiftY + ")");
          }
        });


        anchorNode.call(updateNode);

        link.call(updateLink);
        anchorLink.call(updateLink);

      });

      function rescale() {
        trans=d3.event.translate;
        scale=d3.event.scale;

        vis.attr("transform",
            "translate(" + trans + ")"
            + " scale(" + scale + ")");
      }


    </script>
  </body>
</html>
  FILE
end


if __FILE__ == $0
  filehash = {}
  links = []
  weights = []

  filenames = `cd "$(git rev-parse --show-toplevel)"; git ls-files --full-name`.split
  filenames.each do |filename|
    unless filehash.keys.include? filename
      filehash[filename] = filehash.length
    end
  end

  observation_filenames = observation.reject{|o|!o}.keys
  ob_filenames = {}.tap do |hash|
    observation_filenames.each do |of|
      hash[of] = filehash.delete of
    end
  end

  ob_filenames.each do |k1, v1|
    ob_filenames.each do |k2, v2|
      next if k1 == k2
      weights << 2
      weights << 2
      links << [v2, v1]
      links << [v1, v2]
    end
  end

  hash = `git rev-parse HEAD`.chomp[0..9]
  commit_matrix = retrieve_matrix hash
  predictor = Predictor.new observation, commit_matrix

  filehash.keys.each do |filename|
    ob_filenames.each do |fnam,v|
      links << [v, filehash[filename]]
      weights << predictor.file_similarity(filename, fnam) / filehash.keys.size
    end
  end

  filehash.merge! ob_filenames

  `rm graph_file.html`
  File.open('graph_file.html', 'w+') { |f| f.write html_file(filehash, links, weights, ob_filenames.keys)}

end

