using { TravelService } from './travel-service';

extend service TravelService with {

  /**
   * Accept a travel, moving its status from Open to Accepted.
   * UNBOUND -> visible to MCP as the `call` tool.
   */
  action acceptTravelById(travel : Integer, note : String) returns {
    ID     : Integer;
    Status : String;
    note   : String;
  };

  /**
   * Total revenue per agency over a date range.
   * UNBOUND function -> also reachable via `call`.
   */
  function revenueByAgency(from : Date, to : Date) returns array of {
    Agency   : String;
    revenue  : Decimal;
    travels  : Integer;
  };
}

//
// A BOUND action, for contrast. MCP collects only service-namespace children
// (srv.actions), so anything bound to an entity is INVISIBLE to agents.
//
extend TravelService.Travels with actions {
  action rejectTravel() returns TravelService.Travels;
}
