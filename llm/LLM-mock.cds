using { LLM } from './LLM';

/** Local, offline implementation. Selected by the default profile. */
annotate LLM with @impl: './mock.js';
