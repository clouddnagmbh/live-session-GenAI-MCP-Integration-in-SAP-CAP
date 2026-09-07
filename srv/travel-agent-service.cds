using { TravelService } from './travel-service';
using { sap.capire.travels as our } from '../db/schema';

//
// A TAILORED MCP surface.
//
// Branch 06 exposed the whole TravelService, and the agent saw things nobody
// meant to publish: @cap-js/ai's Travels_Recommendations / Bookings_Recommendations
// companion entities, draft columns like IsActiveEntity, and every managed
// field (createdBy, modifiedAt, ...).
//
// Designing the agent's surface explicitly fixes all of that at once, and it is
// what capire recommends. Note this service is MCP-only -- no @odata.
//
/**
 * Read-only travel reporting surface, designed for AI agents.
 * Every entity and element here was chosen deliberately.
 */
@mcp
@mcp.instructions: 'Read-only travel booking data for reporting. Status codes: O=Open, A=Accepted, X=Rejected. Use query with CQL SELECT statements. Prices are in the travel currency.'
@(requires: ['travel-admin','travel-agent','travel-viewer'])
service TravelAgentService {

  /** A booked travel: who is going where, through which agency, at what price. */
  @readonly entity Travels as projection on our.Travels {
    ID,
    Description,
    BeginDate,
    EndDate,
    TotalPrice,
    Currency.code as Currency,
    Status.name   as Status,
    Agency.Name   as Agency,
    Agency.City   as AgencyCity
  }

  /** A travel agency and the city it operates from. */
  @readonly entity Agencies as projection on our.TravelAgencies {
    ID, Name, City
  }
}

annotate TravelAgentService with @cds.query.limit: { default: 20, max: 100 };

//
// The convergence: a GENERATIVE capability exposed as a governed CAP operation.
//
// The agent does not generate the recommendation. CAP does — behind an unbound
// function, with our data, our projection, our authorization and our prompt.
// The agent just calls a tool.
//
extend service TravelAgentService with {

  /**
   * Recommend a travel agency for a free-text wish.
   * Reads the agencies this caller is allowed to see, puts them in the prompt
   * and asks the LLM to choose one. The prompt is built by CAP, not by the
   * agent, so the caller never decides what the model gets to see.
   */
  function recommendAgency(wish : String) returns {
    wish   : String;
    answer : String;
    model  : String;
    mocked : Boolean;
  };
}
