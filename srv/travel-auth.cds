using { TravelService } from './travel-service';

//
// Standard CAP authorization. @cap-js/mcp honours it by recomputing the tool
// list and the entity/action enums PER REQUEST, from the caller's roles.
//
annotate TravelService with @(requires: ['travel-admin','travel-agent','travel-viewer']);

annotate TravelService.Travels with @(restrict: [
  { grant: 'READ',  to: ['travel-admin','travel-agent','travel-viewer'] },
  { grant: 'WRITE', to: ['travel-admin'] }
]);

// Customers are personal data: agents and admins only, not viewers.
annotate TravelService.Customers with @(restrict: [
  { grant: 'READ', to: ['travel-admin','travel-agent'] }
]);

// Only admins may accept a travel.
annotate TravelService.acceptTravelById with @(requires: 'travel-admin');

//
// There is no @mcp.ignore. Use @cds.api.ignore to hide entities, elements and
// actions from every API -- MCP included.
//
annotate TravelService.Customers with { Email @cds.api.ignore };
annotate TravelService.revenueByAgency with @cds.api.ignore;
