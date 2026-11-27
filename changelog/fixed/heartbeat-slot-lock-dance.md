Activity heartbeats release the Ruby GVL while calling Core, preventing deadlock when a custom activity slot notification needs a Ruby callback while Core holds its activity mutex.
