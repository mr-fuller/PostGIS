In developing our Congestion Management Plan, TMACOG came up with locations of intersections and links projected to be Level of Service D, E, or F based on our travel demand model, and I wanted to convert the points to linearly-referenced events so I can merge all locations into a line layer that I can use in a Crowdsourcing app to solicit feedback from other jurisdictions. 

There are separate sql files for Ohio and Michigan because the LRS schema was different for each state, but that could change if I figure out how to combine them if it makes sense to do so.

The sql is mostly adapted from the Boundless Geo tutorial at http://workshops.boundlessgeo.com/postgis-intro/linear_referencing.html
