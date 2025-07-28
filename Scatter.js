// scatter.js

// 1. Setup and Expanded Background
svg.selectAll("*").remove();

const margin = { top: 30, right: 180, bottom: 90, left: 70 };
const expandedWidth = width + margin.right + 40;
svg
  .attr("viewBox", [0, 0, expandedWidth, height])
  .style("background-color", "black");

svg.append("rect")
  .attr("width", expandedWidth)
  .attr("height", height)
  .attr("fill", "black")
  .lower();

const w = width - margin.left - margin.right;
const h = height - margin.top - margin.bottom;

const g = svg.append("g")
  .attr("transform", `translate(${margin.left},${margin.top})`);

g.append("rect")
  .attr("width", w)
  .attr("height", h)
  .attr("fill", "black");

// 2. Scales
const x = d3.scaleLinear()
  .domain(d3.extent(data, d => +d[options.xvar])).nice()
  .range([0, w]);

const y = d3.scaleLinear()
  .domain(d3.extent(data, d => +d[options.yvar])).nice()
  .range([h, 0]);

const rScale = d3.scaleSqrt()
  .domain(d3.extent(data, d => +d[options.sizevar] || 1))
  .range([3, 14]);

// 3. Country list and color scale (must come before any .fill(colorScale))
const countries = [...new Set(data.map(d => d.Country))];
const colorScale = d3.scaleOrdinal()
  .domain(countries)
  .range(d3.schemeCategory10);

// 4. Dynamic “K/M” Tick Formatting
function makeFormatter(variable) {
  const domain = d3.extent(data, d => +d[variable]);
  const maxVal = Math.max(Math.abs(domain[0]), Math.abs(domain[1]));
  let factor = 1, suffix = "";
  if (maxVal >= 1e6) {
    factor = 1e6; suffix = " (Millions)";
  } else if (maxVal >= 1e3) {
    factor = 1e3; suffix = " (Thousands)";
  }
  const fmt = d3.format(".1f");
  return {
    tickFormat: d => fmt(d / factor),
    labelText: variable + suffix,
    suffix
  };
}

const xFmt = makeFormatter(options.xvar);
const yFmt = makeFormatter(options.yvar);

// 5. Neon Glow Filter & Axes with Tilted Ticks
const defs = svg.append("defs");
const glow = defs.append("filter").attr("id", "glow");
glow.append("feGaussianBlur").attr("stdDeviation", "2").attr("result", "coloredBlur");
const feMerge = glow.append("feMerge");
feMerge.append("feMergeNode").attr("in", "coloredBlur");
feMerge.append("feMergeNode").attr("in", "SourceGraphic");

const xAxis = g.append("g")
  .attr("class", "x-axis")
  .attr("transform", `translate(0,${h})`)
  .call(d3.axisBottom(x).tickFormat(xFmt.tickFormat));

xAxis.selectAll("path, line")
  .attr("stroke", "#66fcf1")
  .attr("stroke-width", 2)
  .attr("filter", "url(#glow)");

xAxis.selectAll("text")
  .attr("fill", "#c5c6c7")
  .attr("font-family", "'Press Start 2P', cursive")
  .attr("font-size", "10px")
  .attr("transform", "rotate(-40)")
  .attr("text-anchor", "end");

const yAxis = g.append("g")
  .attr("class", "y-axis")
  .call(d3.axisLeft(y).tickFormat(yFmt.tickFormat));

yAxis.selectAll("path, line")
  .attr("stroke", "#66fcf1")
  .attr("stroke-width", 2)
  .attr("filter", "url(#glow)");

yAxis.selectAll("text")
  .attr("fill", "#c5c6c7")
  .attr("font-family", "'Press Start 2P', cursive")
  .attr("font-size", "10px");

// 6. Axis Titles in Outer SVG Space
svg.append("text")
  .attr("x", margin.left + w / 2)
  .attr("y", height - 15)
  .attr("fill", "#66fcf1")
  .attr("font-size", "10px")
  .attr("text-anchor", "middle")
  .attr("font-family", "'Press Start 2P', cursive")
  .text(xFmt.labelText);

svg.append("text")
  .attr("transform", "rotate(-90)")
  .attr("x", -margin.top - h / 2)
  .attr("y", 15)
  .attr("fill", "#66fcf1")
  .attr("font-size", "10px")
  .attr("text-anchor", "middle")
  .attr("font-family", "'Press Start 2P', cursive")
  .text(yFmt.labelText);

// 7. Tooltip
const tooltip = d3.select("body").append("div")
  .attr("class", "d3-tooltip")
  .style("position", "absolute")
  .style("background", "#1f2833")
  .style("color", "#c5c6c7")
  .style("padding", "6px")
  .style("border-radius", "4px")
  .style("font-family", "'Press Start 2P', cursive")
  .style("font-size", "10px")
  .style("display", "none");

// 8. Points + Animation + Tooltips
g.selectAll("circle")
  .data(data)
  .join("circle")
    .attr("cx", d => x(+d[options.xvar]))
    .attr("cy", d => y(+d[options.yvar]))
    .attr("r", 0)
    .attr("fill", d => colorScale(d.Country))
    .attr("opacity", 0.8)
    .on("mouseover", function(event, d) {
      tooltip.style("display", "block")
        .html(
          `<strong>${d.Country}</strong><br>` +
          `${options.xvar}: ${xFmt.tickFormat(+d[options.xvar])}${xFmt.suffix}<br>` +
          `${options.yvar}: ${yFmt.tickFormat(+d[options.yvar])}${yFmt.suffix}`
        );
    })
    .on("mousemove", function(event) {
      tooltip.style("left", (event.pageX + 10) + "px")
             .style("top",  (event.pageY - 28) + "px");
    })
    .on("mouseout", function() {
      tooltip.style("display", "none");
    })
    .transition()
    .duration(800)
    .attr("r", d => options.plotType === "bubble"
                   ? rScale(+d[options.sizevar])
                   : 4);

// 9. Country Legend – Outside Plot
const legend = svg.append("g")
  .attr("class", "legend")
  .attr("transform", `translate(${width + 40},${margin.top})`);

countries.forEach((country, i) => {
  const row = legend.append("g")
    .attr("transform", `translate(0, ${i * 18})`);

  row.append("rect")
    .attr("width", 12)
    .attr("height", 12)
    .attr("fill", colorScale(country));

  row.append("text")
    .attr("x", 16)
    .attr("y", 10)
    .attr("fill", "#c5c6c7")
    .attr("font-size", "10px")
    .attr("font-family", "'Press Start 2P', cursive")
    .text(country);
});

// 10. Bubble Size Legend (Optional)
if (options.plotType === "bubble") {
  const rLegend = svg.append("g")
    .attr("class", "r-legend")
    .attr("transform", `translate(${margin.left},${height - margin.bottom + 10})`);

  const legendSizes = [5, 20, 50];
  legendSizes.forEach((val, i) => {
    const xOffset = i * 60;
    rLegend.append("circle")
      .attr("cx", xOffset)
      .attr("cy", 20)
      .attr("r", rScale(val))
      .attr("fill", "#66fcf1")
      .attr("opacity", 0.6);

    rLegend.append("text")
      .attr("x", xOffset)
      .attr("y", 50)
      .attr("text-anchor", "middle")
      .attr("fill", "#c5c6c7")
      .attr("font-size", "10px")
      .attr("font-family", "'Press Start 2P', cursive")
      .text(val);
  });

  rLegend.append("text")
    .attr("x", 0)
    .attr("y", 70)
    .attr("fill", "#66fcf1")
    .attr("font-size", "10px")
    .attr("font-family", "'Press Start 2P', cursive")
    .text(options.sizevar);
}
