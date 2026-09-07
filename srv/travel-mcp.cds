using { TravelService } from './travel-service';

//
// Expose TravelService over MCP, alongside OData.
//
// KEEPING @odata IS MANDATORY. Any protocol annotation REPLACES the default
// protocol set, so `annotate TravelService with @mcp;` on its own would leave
// only /mcp/travel — killing the Fiori preview and every OData call in this repo.
//
annotate TravelService with @odata @mcp
  @mcp.instructions: 'This service manages travel bookings. Use `describe` to explore Travels, Bookings, Customers, TravelAgencies and Currencies. Use `query` with a CQL SELECT statement to read data. Use `call` for unbound actions. Travel status codes are O=Open, A=Accepted, X=Rejected.';
