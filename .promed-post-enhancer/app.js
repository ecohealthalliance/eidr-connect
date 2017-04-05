import 'd3';
import picoModal from 'picomodal';
import './EventDrops/lib/eventDrops.js';
import './EventDrops/style.css';
import './styles.css';
import {html, safeHtml} from 'common-tags'
const EIDR_CONNECT_URL = "https://eidr-connect.eha.io";

const FONT_SIZE = 16; // in pixels
const TOOLTIP_WIDTH = 30; // in rem
const showTooltip = (article)=> {
  d3.select('body').selectAll('.tooltip').remove();

  const tooltip = d3.select('body')
  .append('div')
  .attr('class', 'tooltip')
  .style('opacity', 0); // hide it by default

  // show the tooltip with a small animation
  tooltip.transition()
  .duration(200)
  .each('start', function start(){
    d3.select(this).style('block');
  })
  .style('opacity', 1);

  const rightOrLeftLimit = FONT_SIZE * TOOLTIP_WIDTH;
  const direction = d3.event.pageX > rightOrLeftLimit ? 'right' : 'left';

  const ARROW_MARGIN = 1.65;
  const ARROW_WIDTH = FONT_SIZE;
  const left = direction === 'right' ?
    d3.event.pageX - rightOrLeftLimit :
    d3.event.pageX - ARROW_MARGIN * FONT_SIZE - ARROW_WIDTH / 2;

  const formattedURL = article.url.startsWith("http") ? article.url : "https://" + article.url;
  tooltip.html(safeHtml`
    <div class="marker">
      <div class="content">
        <p>
          <a href="${formattedURL}">${article.title || formattedURL}</a>
        </p>
        <p>
          Published on <span class="date">${(new Date(article.publishDate)).toLocaleString()}</span>
        </p>
      </div>
    </div>
  `)
  .classed(direction, true)
  .style({
    left: `${left}px`,
    top: (d3.event.pageY + 16) + 'px',
  });
};

const hideTooltip = () => {
  d3.select('.tooltip').transition()
  .duration(200)
  .each('end', function end(){
    this.remove();
  })
  .style('opacity', 0);
};

const pointAdd = (point0, ...points) => point0.map((el, idx)=>{
    return points.reduce((sofar, el2)=>sofar+el2[idx], el);
  });
const pointScale = (p, s) => p.map((el, idx)=>{
    return el * s;
  });

var enhancing = false;
if(window.obs) window.obs.disconnect();
const enhance = (target)=>{
  if(enhancing) return;
  enhancing  = true;
  let printLink = document.querySelector(".printable a");
  if(!printLink) return enhancing=false;
  let postIdMatch = printLink.onclick.toString().match(/post\/(\d+)/);
  if(!postIdMatch) return enhancing=false;
  let postId = window.__debugPostId || postIdMatch[1];
  let url = "http://promedmail.org/post/" + postId;
  let eidrConnectUrl = window.__debugEidrConnectUrl || EIDR_CONNECT_URL;
  $.getJSON(eidrConnectUrl + "/api/events-with-source", {
    url: url
  }, (events)=>{
    if(!events || events.length === 0) return enhancing=false;
    let enhancementHTML = `
      <p class="eidr-connect-events">EIDR-Connect Events
        [<a id="aboutEidrConnect">?</a>]:&nbsp;
        ${events.map((event)=>{
          return safeHtml`<a href="https://eidr-connect.eha.io/curated-events/${event._id}">
            ${event.eventName}
          </a>`;
        }).join(", ")}
      </p>
      <div id="plotContainer">
        <button class="zoom-btn zoom-out">-</button>
        <button class="zoom-btn zoom-in">+</button>
        <p class="timeline-title">Event timeline:</p>
        <div class="eidr-chart"></div>
      </div>
    `;
    let $seeAlso = $(target).find("h2");
    if($seeAlso.length > 0) $seeAlso.before(enhancementHTML);
    else $(target).append(enhancementHTML);
    $("#aboutEidrConnect").click(()=>picoModal(
      `This information is being displayed because a curator associated
      this post with an Emerging Infectious Disease event in EIDR-Connect.
      The timeline below shows all the other ProMED posts associated with the
      same EID event as this one. Additional information about the EID event,
      such as case count graphs and maps,
      is available on the EIDR-Connect website.`
      ).show());
    var minPubDate = new Date();
    events.forEach((event)=>{
      event.articles.forEach((article)=>{
        if(!article.publishDate) return;
        let publishDate = new Date(article.publishDate);
        if(publishDate < minPubDate){
          minPubDate = publishDate;
        }
      });
    });
    const chart = d3.chart.eventDrops()
    //Start a day before the first date
    .start(new Date(minPubDate.getTime() - 3600000 * 24))
    .end(new Date(Date.now() + 3600000 * 24))
    .margin({
      top: 50, bottom: 0, left: 0, right: 0
    })
    .labelsWidth(0)
    .eventColor((d, i)=>{
      return d.url === url ? '#ff0000' : '#0d73bb';
    })
    .date(a => new Date(a.publishDate))
    .click(showTooltip);

    $(document).click((evt)=>{
      if(evt.target.matches(".drop")) return;
      if(!$(evt.target).closest('.tooltip').length) hideTooltip();
    });

    const element = d3.select('.eidr-chart').datum(events.map((event)=>({
      name: event.eventName,
      data: event.articles.filter(a=>a.publishDate)
    })));

    chart(element);

    const zoom = element[0][0].zoom;
    $(".zoom-in").click(()=>zoomBy(1.5));
    $(".zoom-out").click(()=>zoomBy(1/1.5));

    let zoomBy = (factor) => {
      // Temporarily set zoom center
      zoom.center([$(".eidr-chart").width() / 2, 0]);
      // Based on http://bl.ocks.org/mbostock/7ec977c95910dd026812
      element.call(zoom.event);
      let center0 = zoom.center();
      let translate0 = zoom.translate();
      let coordinates0 = pointScale(
        pointAdd(center0,  pointScale(zoom.translate(), -1)),
        1 / zoom.scale()
      );
      zoom.scale(zoom.scale() * factor);
      let center1 = pointAdd(
        zoom.translate(),
        pointScale(coordinates0, zoom.scale())
      );
      zoom.translate(pointAdd(translate0, center0, pointScale(center1, -1)));
      element.transition().duration(500).call(zoom.event);
      zoom.center(null);
    };
    // A timeout is used for debouncing
    setTimeout(()=>{
      enhancing = false;
    }, 100);
  });
};
window.previewSectionPromise = new Promise((resolve, reject)=>{
  let remainingAttempts = 10;
  const id = setInterval(()=>{
    remainingAttempts--;
    const previewSection = document.querySelector("#preview");
    if(previewSection) {
      clearInterval(id);
      resolve(previewSection);
    } else if(remainingAttempts <= 0){
      clearInterval(id);
    }
  }, 100);
});
previewSectionPromise.then((previewSection)=>{
  window.obs = new MutationObserver((mutations)=>{
    enhance(previewSection);
  });
  window.obs.observe(previewSection, { childList: true });
  enhance(previewSection);
});
