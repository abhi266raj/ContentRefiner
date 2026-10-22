import ContentRefinerCommand
#if os(Windows)
import ucrt
#elseif os(Linux)
import Glibc
#else
import Darwin
#endif
exit(await ContentRefinerCommand.run())
