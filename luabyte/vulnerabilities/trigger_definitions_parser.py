import json
from collections import namedtuple
from ipdb import set_trace

Definitions = namedtuple(
    'Definitions',
    (
        'sources',
        'sinks'
    )
)

class Source:
    def __init__(self, trigger_word, source_type, idx_list):
        self.trigger_word = trigger_word
        self.type = source_type # determine the source type, "param": function params, "ret": function return value
        self.idx = idx_list # used for function call param


class Sink:
    def __init__(
        self, trigger_word, idx,
        sanitisers,
    ):
        self.trigger_word = trigger_word
        self.idx = idx
        self.sanitisers = sanitisers or []



def parse(trigger_word_file):
    """Parse the file for source and sink definitions.

    Returns:
       A definitions tuple with sources and sinks.
    """
    with open(trigger_word_file) as fd:
        triggers_dict = json.load(fd)

    sources = list()
    for trigger_work, source_info in triggers_dict['sources'].items():
        source_type = source_info["type"]
        idx_list = source_info["idx"] if "idx" in source_info else None
        if isinstance(idx_list, list):
            for idx in idx_list:
                sources.append(Source(trigger_work, source_type, idx))
        else:
            sources.append(Source(trigger_work, source_type, None))
    
    sinks = list()
    for trigger_work, sink_info in triggers_dict['sinks'].items():
        sanitisers = sink_info["sanitisers"]
        idx_list = sink_info["idx"] if "idx" in sink_info else None
        if isinstance(idx_list, list):
            for idx in idx_list:
                sinks.append(Sink(trigger_work, idx, sanitisers))
        else:
            raise ValueError("configuration parse error: sink info error")
    return Definitions(sources, sinks)
