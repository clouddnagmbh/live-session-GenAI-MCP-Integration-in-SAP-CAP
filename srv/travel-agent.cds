using { TravelAgentService } from './travel-agent-service';

//
// A CAP-level agent, served over A2A at /a2a/travel-agent.
//
// @cap-js/agents turns the service's entities and operations into MCP tools
// (describe / query / call, the same three as branch 06) and runs a ReAct loop
// against the model configured in cds.requires.llm. Nothing else is needed.
//
annotate TravelAgentService with @agent;
