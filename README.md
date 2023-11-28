# Core application/enviriment to run plugins

## Erlang/OTP event bus architecture

```
          -----------
         | ppool_app |
          ___________
                  |
                  | spawn pool manager
                  |
  init parent pool --->  -----------
      ----------------> | ppool_sup | <-----------
                         ___________               |
                         |    |                    |
                         |    | start pool api     | start/stop child pool
                         |    |                    |
                         |    |                    |
                         |    |                    |
   start/stop pool tree  |    |     -----------    |
                         |     ->  | ppool     | --
                         |          ___________
                         |
                         |
                         |          --------------------------
                          -------> | ppool_master_worker_sup  |
                                    __________________________
                                     |
                                     |     --------------
                     --------------- |--->| ppool_worker | / ETS workers map/pids/req+res states
                     |             ---|---- ______________ --
                     |            |   |                      | pub/sub pool
                     |            |   |     -------------- <-
                     |            |   |--->| ppool_ev     | event handler  (route messages)
             create new workear   |   |     ______________
                     |            |   |
                     |            |   |     ------------------
                     |            |    --->| ppool_worker_sup | 
                     |             ------->  __________________
                     |                       |
        send message |                       |     --------------
                     |                       |--->| port_worker |
                     |---------------------------> ______________
                     |                       |
                     |                       |     --------------
                     |                       |--->| erl_worker  |
                     |---------------------------> ______________

```
